# frozen_string_literal: true

require_relative 'test_helper'

# State changes through the model are event-only: a direct write of a
# different state raises StateMachines::DirectStateAssignment, while raw
# persistence APIs stay an explicit escape hatch outside the machine.
# See https://github.com/state-machines/state_machines-activerecord/issues/47
module DirectStateAssignmentHelpers
  private

  # Builds a parked/idling vehicle model with a +name+ column and a counter
  # of transition callbacks.
  #
  # @return [Class] the model class
  def vehicle_model(&block)
    new_model do
      connection.add_column table_name, :name, :string
      attr_accessor :transitions_run

      state_machine initial: :parked do
        after_transition { |record| record.transitions_run = (record.transitions_run || 0) + 1 }

        event(:ignite) { transition parked: :idling }
        event(:park) { transition idling: :parked }
      end

      class_eval(&block) if block
    end
  end

  # Writes the raw attribute, bypassing every setter.
  def bypass_setter(record, name, value)
    record.instance_variable_get(:@attributes).write_from_user(name.to_s, value)
  end
end

class MachineWithDirectStateAssignmentTest < BaseTestCase
  include DenyDirectAssignment
  include DirectStateAssignmentHelpers

  def setup
    @model = vehicle_model
    @record = @model.create!
  end

  def test_should_raise_on_setter_with_different_state
    error = assert_raises(StateMachines::DirectStateAssignment) { @record.state = 'idling' }

    assert_equal 'parked', @record.state
    refute_predicate @record, :changed?
    assert_same @record, error.object
    assert_equal :state, error.machine.name
    assert_equal :state, error.attribute
    assert_equal 'parked', error.from
    assert_equal 'idling', error.to
  end

  def test_should_name_machine_values_and_alternatives_in_message
    error = assert_raises(StateMachines::DirectStateAssignment) { @record.state = :idling }

    assert_includes error.message, "#{@model.name}#state"
    assert_includes error.message, 'state machine :state'
    assert_includes error.message, '"parked"'
    assert_includes error.message, ':idling'
    assert_includes error.message, 'state_event'
    assert_includes error.message, 'update_column'
    assert_includes error.message, 'reload'
  end

  def test_should_allow_assigning_same_state
    @record.state = 'parked'
    @record.state = :parked

    assert_equal 'parked', @record.state
    refute_predicate @record, :changed?
    assert_nil @record.transitions_run
  end

  def test_should_raise_on_assign_attributes
    assert_raises(StateMachines::DirectStateAssignment) { @record.assign_attributes(state: 'idling') }
    assert_equal 'parked', @record.state
  end

  def test_should_raise_on_update_without_saving
    assert_raises(StateMachines::DirectStateAssignment) { @record.update(name: 'Herbie', state: 'idling') }
    assert_equal 'parked', @record.reload.state
    assert_nil @record.name
  end

  def test_should_raise_on_bracket_writer
    assert_raises(StateMachines::DirectStateAssignment) { @record[:state] = 'idling' }
    assert_raises(StateMachines::DirectStateAssignment) { @record['state'] = 'idling' }
    assert_equal 'parked', @record.state
  end

  def test_should_raise_on_write_attribute
    assert_raises(StateMachines::DirectStateAssignment) { @record.write_attribute(:state, 'idling') }
    assert_equal 'parked', @record.state
  end

  def test_should_raise_on_update_attribute
    assert_raises(StateMachines::DirectStateAssignment) { @record.update_attribute(:state, 'idling') }
    assert_equal 'parked', @record.reload.state
  end

  def test_should_allow_other_attributes
    assert @record.update(name: 'Herbie', state: 'parked')
    assert_equal 'Herbie', @record.reload.name
  end

  def test_should_transition_through_events
    assert @record.ignite
    assert_equal 'idling', @record.reload.state
    assert @record.park!
    assert_equal 'parked', @record.reload.state
  end

  def test_should_transition_through_state_event
    @record.state_event = 'ignite'

    assert @record.save
    assert_equal 'idling', @record.reload.state
    assert @record.update(state_event: 'park')
    assert_equal 'parked', @record.reload.state
  end

  def test_should_reject_state_submitted_with_state_event
    assert_raises(StateMachines::DirectStateAssignment) { @record.update(state_event: 'ignite', state: 'idling') }
    assert_raises(StateMachines::DirectStateAssignment) { @record.update(state: 'idling', state_event: 'ignite') }
    assert_equal 'parked', @record.reload.state
  end

  def test_should_not_record_a_refusal
    assert_raises(StateMachines::DirectStateAssignment) { @record.state = 'idling' }

    assert_nil @record.ignite_refusal
    assert_nil @record.park_refusal
  end

  def test_should_allow_reload_after_raw_update
    @model.where(id: @record.id).update_all(state: 'idling')

    assert_equal 'idling', @record.reload.state
    assert @record.park
  end
end

class MachineWithDirectStateAssignmentInCallbacksTest < BaseTestCase
  include DenyDirectAssignment
  include DirectStateAssignmentHelpers

  def test_should_raise_when_after_transition_overwrites_destination
    model = vehicle_model { state_machine { after_transition(on: :ignite) { |record| record.state = 'parked' } } }
    record = model.create!

    assert_raises(StateMachines::DirectStateAssignment) { record.ignite }
    assert_equal 'parked', record.reload.state
  end

  def test_should_raise_when_before_transition_writes_destination
    model = vehicle_model { state_machine { before_transition(on: :ignite) { |record| record.state = 'idling' } } }
    record = model.create!

    assert_raises(StateMachines::DirectStateAssignment) { record.ignite }
    assert_equal 'parked', record.reload.state
  end

  def test_should_raise_when_save_callback_writes_state
    model = vehicle_model { before_save { self.state = 'idling' if name == 'sneaky' } }
    record = model.create!

    assert_raises(StateMachines::DirectStateAssignment) { record.update(name: 'sneaky') }
    assert_equal 'parked', record.reload.state
  end

  def test_should_raise_when_after_initialize_writes_state
    model = vehicle_model { after_initialize { self.state = 'idling' } }

    assert_raises(StateMachines::DirectStateAssignment) { model.new }
  end

  def test_should_roll_back_state_on_failed_save
    model = vehicle_model { before_save { throw :abort if name == 'abort' } }
    record = model.create!
    record.name = 'abort'

    refute record.ignite
    assert_equal 'parked', record.state
  end

  def test_should_initialize_dynamic_initial_state
    model = new_model do
      attr_accessor :ready

      state_machine initial: ->(record) { record.ready ? :idling : :parked } do
        event(:ignite) { transition parked: :idling }
      end
    end

    assert_equal 'parked', model.new.state
    assert_equal 'idling', model.new(ready: true).state
    assert_equal 'idling', model.new(ready: true, state: 'idling').state
    assert_raises(StateMachines::DirectStateAssignment) { model.new(state: 'idling') }
  end
end

class MachineWithDirectStateAssignmentOnNewRecordTest < BaseTestCase
  include DenyDirectAssignment
  include DirectStateAssignmentHelpers

  def setup
    @model = vehicle_model
  end

  def test_should_allow_building_with_initial_state
    assert_equal 'parked', @model.new(state: 'parked').state
    assert_equal 'parked', @model.new(state: :parked).state
    assert_equal 'parked', @model.create!(state: 'parked').reload.state
  end

  def test_should_raise_when_building_with_other_state
    assert_raises(StateMachines::DirectStateAssignment) { @model.new(state: 'idling') }
  end

  def test_should_raise_when_creating_with_other_state
    assert_raises(StateMachines::DirectStateAssignment) { @model.create!(state: 'idling') }
    assert_raises(StateMachines::DirectStateAssignment) { @model.create(state: 'idling') }
    assert_equal 0, @model.count
  end

  def test_should_raise_when_scope_pins_other_state
    assert_equal 'parked', @model.where(state: 'parked').new.state
    assert_raises(StateMachines::DirectStateAssignment) { @model.where(state: 'idling').new }
    assert_raises(StateMachines::DirectStateAssignment) { @model.find_or_create_by(state: 'idling') }
  end

  def test_should_raise_when_initializer_block_writes_other_state
    assert_raises(StateMachines::DirectStateAssignment) { @model.new { |record| record.state = 'idling' } }
  end

  def test_should_raise_on_unsaved_record
    record = @model.new

    assert_raises(StateMachines::DirectStateAssignment) { record.state = 'idling' }
    assert_equal 'parked', record.state
  end

  def test_should_raise_without_initial_state
    model = new_model do
      state_machine { event(:ignite) { transition nil => :idling } }
    end

    assert_nil model.new.state
    assert_raises(StateMachines::DirectStateAssignment) { model.new(state: 'idling') }
    assert_equal 'idling', model.new.tap(&:ignite).state
  end

  def test_should_allow_schema_default_initial_state
    model = new_model(false) do
      connection.create_table(table_name, force: true) { |t| t.string(:state, default: 'parked') }
      reset_column_information
      state_machine { state :parked, :idling }
    end

    assert_equal 'parked', model.new(state: 'parked').state
    assert_raises(StateMachines::DirectStateAssignment) { model.new(state: 'idling') }
  end
end

class MachineWithDirectStateAssignmentBackstopTest < BaseTestCase
  include DenyDirectAssignment
  include DirectStateAssignmentHelpers

  def setup
    @model = vehicle_model
    @record = @model.create!
  end

  def test_should_refuse_to_save_bypassed_state
    bypass_setter(@record, :state, 'idling')

    error = assert_raises(StateMachines::DirectStateAssignment) { @record.save }
    assert_equal 'parked', error.from
    assert_equal 'idling', error.to
    assert_equal 'parked', @model.find(@record.id).state
  end

  def test_should_refuse_to_save_bypassed_state_without_validation
    bypass_setter(@record, :state, 'idling')

    assert_raises(StateMachines::DirectStateAssignment) { @record.save(validate: false) }
    assert_raises(StateMachines::DirectStateAssignment) { @record.save! }
    assert_raises(StateMachines::DirectStateAssignment) { @record.update_attribute(:name, 'Herbie') }
    assert_equal 'parked', @model.find(@record.id).state
  end

  def test_should_refuse_to_save_in_place_mutation
    @record.state.replace('idling')

    assert_raises(StateMachines::DirectStateAssignment) { @record.save }
    assert_equal 'parked', @model.find(@record.id).state
  end

  def test_should_refuse_to_save_state_bypassed_in_before_save
    model = vehicle_model do
      before_save { instance_variable_get(:@attributes).write_from_user('state', 'idling') if name == 'sneaky' }
    end
    record = model.create!

    assert_raises(StateMachines::DirectStateAssignment) { record.update(name: 'sneaky') }
    assert_equal 'parked', model.find(record.id).state
  end

  def test_should_refuse_to_transition_from_bypassed_state
    bypass_setter(@record, :state, 'idling')
    @record.state_event = 'park'

    assert_raises(StateMachines::DirectStateAssignment) { @record.save }
    assert_equal 'parked', @model.find(@record.id).state
  end

  def test_should_refuse_to_validate_a_transition_from_bypassed_state
    bypass_setter(@record, :state, 'idling')
    @record.state_event = 'park'

    assert_raises(StateMachines::DirectStateAssignment) { @record.valid? }
  end

  def test_should_save_unsaved_event_transition
    assert @record.ignite(false)
    assert @record.save
    assert_equal 'idling', @record.reload.state
  end

  def test_should_save_dup_with_its_state
    @record.ignite
    copy = @record.dup

    assert copy.save
    assert_equal 'idling', copy.reload.state
  end

  def test_should_not_legitimize_bypassed_state_on_dup
    bypass_setter(@record, :state, 'idling')

    assert_raises(StateMachines::DirectStateAssignment) { @record.dup.save }
    assert_equal 1, @model.count
  end

  def test_should_save_after_restoring_attributes
    assert @record.ignite(false)
    @record.restore_attributes

    assert_equal 'parked', @record.state
    assert @record.save
  end
end

class MachineWithDirectStateAssignmentRawPersistenceTest < BaseTestCase
  include DenyDirectAssignment
  include DirectStateAssignmentHelpers

  def setup
    @model = vehicle_model
    @record = @model.create!
  end

  def test_should_update_column_without_callbacks
    assert @record.update_column(:state, 'idling')

    assert_equal 'idling', @record.state
    assert_equal 'idling', @model.find(@record.id).state
    assert_nil @record.transitions_run
    assert @record.park
  end

  def test_should_update_columns
    assert @record.update_columns(state: 'idling', name: 'Herbie')
    assert_equal 'idling', @model.find(@record.id).state
    assert @record.save
  end

  def test_should_leave_other_instances_stale_until_reload
    other = @model.find(@record.id)
    @model.where(id: @record.id).update_all(state: 'idling')

    assert_equal 'parked', other.state
    assert_equal 'idling', other.reload.state
  end

  def test_should_insert_and_upsert
    @model.insert_all([{ state: 'idling' }])
    @model.upsert({ id: @record.id, state: 'idling' })

    assert_equal %w[idling idling], @model.order(:id).pluck(:state).sort
    assert_equal 'idling', @record.reload.state
  end
end

class MachineWithDirectStateAssignmentBecomesTest < BaseTestCase
  include DenyDirectAssignment
  include DirectStateAssignmentHelpers

  def setup
    @model = vehicle_model
    table = @model.table_name
    @other = new_model(false) do
      self.table_name = table
      attr_accessor :transitions_run

      state_machine initial: :parked do
        after_transition { |record| record.transitions_run = (record.transitions_run || 0) + 1 }
        event(:ignite) { transition parked: :idling }
      end
    end
    @record = @model.create!
    @record.ignite
  end

  def test_should_preserve_state_without_callbacks
    became = @record.becomes(@other)

    assert_equal 'idling', became.state
    assert_nil became.transitions_run
    assert became.save
  end

  def test_should_not_legitimize_bypassed_state
    bypass_setter(@record, :state, 'parked')
    became = @record.becomes(@other)

    assert_raises(StateMachines::DirectStateAssignment) { became.save }
    assert_equal 'idling', @model.find(@record.id).state
  end

  def test_should_refuse_with_pending_state_event
    @record.state_event = 'park'

    error = assert_raises(StateMachines::PendingStateEvent) { @record.becomes(@other) }
    assert_includes error.message, 'state_event'
  end

  def test_should_refuse_with_prepared_transition
    @record.state_event = 'park'
    assert_predicate @record, :valid?

    assert_raises(StateMachines::PendingStateEvent) { @record.becomes(@other) }
  end
end

class MachineWithDirectStateAssignmentOnIntegerColumnTest < BaseTestCase
  include DenyDirectAssignment

  def setup
    @model = new_model(false) do
      connection.create_table(table_name, force: true) { |t| t.integer(:state) }
      reset_column_information
      state_machine initial: :parked do
        event(:ignite) { transition parked: :idling }
      end
    end
    @record = @model.create!
  end

  def test_should_allow_equivalent_values
    @record.state = :parked
    @record.state = 'parked'
    @record.state = 0

    refute_predicate @record, :changed?
  end

  def test_should_raise_on_different_values
    assert_raises(StateMachines::DirectStateAssignment) { @record.state = 1 }
    assert_raises(StateMachines::DirectStateAssignment) { @record.state = 'idling' }
    assert_equal 'parked', @record.state
  end

  def test_should_allow_building_with_initial_integer
    assert_equal 'parked', @model.new(state: 0).state
    assert_raises(StateMachines::DirectStateAssignment) { @model.new(state: 1) }
  end
end

class MachineWithDirectStateAssignmentOnAliasTest < BaseTestCase
  include DenyDirectAssignment

  def test_should_guard_alias_of_machine_attribute
    model = new_model do
      alias_attribute :vehicle_status, :state
      state_machine initial: :parked do
        event(:ignite) { transition parked: :idling }
      end
    end
    record = model.create!

    assert_raises(StateMachines::DirectStateAssignment) { record.vehicle_status = 'idling' }
    assert_raises(StateMachines::DirectStateAssignment) { record.assign_attributes(vehicle_status: 'idling') }
    assert_raises(StateMachines::DirectStateAssignment) { model.new(vehicle_status: 'idling') }
    assert_equal 'parked', model.new(vehicle_status: 'parked').state
  end

  def test_should_guard_alias_declared_after_machine
    model = new_model do
      state_machine initial: :parked do
        event(:ignite) { transition parked: :idling }
      end
      alias_attribute :vehicle_status, :state
    end
    record = model.create!

    assert_raises(StateMachines::DirectStateAssignment) { record.vehicle_status = 'idling' }
    assert_raises(StateMachines::DirectStateAssignment) { model.new(vehicle_status: 'idling') }
    assert_equal 'parked', model.new(vehicle_status: 'parked').state
  end

  def test_should_guard_column_behind_aliased_machine_attribute
    model = new_model do
      alias_attribute :vehicle_status, :state
      state_machine :status, attribute: :vehicle_status, initial: :parked do
        event(:ignite) { transition parked: :idling }
      end
    end
    record = model.create!

    assert_raises(StateMachines::DirectStateAssignment) { record.state = 'idling' }
    assert_raises(StateMachines::DirectStateAssignment) { record.vehicle_status = 'idling' }
    assert record.ignite
    assert_equal 'idling', record.reload.vehicle_status
  end
end

class MachineWithDirectStateAssignmentOnMultipleMachinesTest < BaseTestCase
  include DenyDirectAssignment

  def setup
    @model = new_model do
      connection.add_column table_name, :alarm_state, :string
      state_machine initial: :parked do
        event(:ignite) { transition parked: :idling }
      end
      state_machine :alarm_state, initial: :active, namespace: :alarm do
        event(:disable) { transition active: :off }
      end
    end
    @record = @model.create!
  end

  def test_should_guard_every_machine
    assert_raises(StateMachines::DirectStateAssignment) { @record.state = 'idling' }
    error = assert_raises(StateMachines::DirectStateAssignment) { @record.alarm_state = 'off' }
    assert_equal :alarm_state, error.machine.name
  end

  def test_should_fire_namespaced_events
    assert @record.disable_alarm
    assert_equal 'off', @record.reload.alarm_state
    assert_equal 'parked', @record.state
  end

  def test_should_build_with_initial_states
    record = @model.new(state: 'parked', alarm_state: 'active')

    assert_equal %w[parked active], [record.state, record.alarm_state]
    assert_raises(StateMachines::DirectStateAssignment) { @model.new(alarm_state: 'off') }
  end
end

class MachineWithDirectStateAssignmentOnSiblingMachinesTest < BaseTestCase
  include DenyDirectAssignment

  def setup
    @model = new_model do
      state_machine initial: :parked do
        event(:ignite) { transition parked: :idling }
      end
      state_machine :public_state, attribute: :state do
        event(:park) { transition idling: :parked }
      end
    end
  end

  def test_should_build_with_initial_state_of_either_machine
    assert_equal 'parked', @model.new(state: 'parked').state
    assert_raises(StateMachines::DirectStateAssignment) { @model.new(state: 'idling') }
  end

  def test_should_transition_through_both_machines
    record = @model.create!

    assert record.ignite
    assert_raises(StateMachines::DirectStateAssignment) { record.state = 'parked' }
    assert record.update(public_state_event: 'park')
    assert_equal 'parked', record.reload.state
  end
end

module DirectStateAssignmentOnTransientAttributeTests
  def setup
    kind = transient_kind
    @model = new_model do
      kind == :accessor ? attr_accessor(:status) : attribute(:status, :string)
      state_machine :status, initial: :one do
        event(:advance) { transition one: :two }
      end
    end
    @record = @model.create!
  end

  def test_should_raise_on_setter
    assert_raises(StateMachines::DirectStateAssignment) { @record.status = 'two' }
    assert_equal 'one', @record.status
  end

  def test_should_allow_same_state
    @record.status = :one
    @record.status = 'one'

    assert_equal 'one', @record.status
  end

  def test_should_raise_when_building_with_other_state
    assert_equal 'one', @model.new(status: 'one').status
    assert_raises(StateMachines::DirectStateAssignment) { @model.new(status: 'two') }
  end

  def test_should_transition_through_events
    assert @record.advance
    assert_equal 'two', @record.status
  end
end

class MachineWithDirectStateAssignmentOnAttrAccessorTest < BaseTestCase
  include DenyDirectAssignment
  include DirectStateAssignmentOnTransientAttributeTests

  private

  def transient_kind = :accessor
end

class MachineWithDirectStateAssignmentOnAttributesApiTest < BaseTestCase
  include DenyDirectAssignment
  include DirectStateAssignmentOnTransientAttributeTests

  def test_should_raise_on_write_attribute
    assert_raises(StateMachines::DirectStateAssignment) { @record.write_attribute(:status, 'two') }
    assert_raises(StateMachines::DirectStateAssignment) { @record[:status] = 'two' }
  end

  private

  def transient_kind = :attribute
end
