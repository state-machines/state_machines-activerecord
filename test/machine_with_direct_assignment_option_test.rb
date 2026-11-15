# frozen_string_literal: true

require_relative 'test_helper'

class MachineWithDirectAssignmentAllowedByDefaultTest < BaseTestCase
  def setup
    @model = new_model do
      state_machine initial: :parked do
        event(:ignite) { transition parked: :idling }
      end
    end
  end

  def test_should_allow_direct_assignment_by_default
    assert_equal :allow, @model.state_machine.direct_assignment
    refute_predicate @model.state_machine, :direct_assignment_denied?
  end

  def test_should_persist_state_written_through_setter
    record = @model.create!
    record.state = 'idling'

    assert record.save
    assert_equal 'idling', record.reload.state
  end

  def test_should_persist_state_written_through_update
    record = @model.create!

    assert record.update(state: 'idling')
    assert_equal 'idling', record.reload.state
  end

  def test_should_create_with_non_initial_state
    assert_equal 'idling', @model.create!(state: 'idling').reload.state
  end

  def test_should_still_fire_events
    record = @model.create!

    assert record.ignite
    assert_equal 'idling', record.reload.state
  end

  def test_should_allow_becomes_with_queued_event
    record = @model.create!
    record.state_event = 'ignite'

    assert_equal 'parked', record.becomes(@model).state
  end
end

class MachineWithDirectAssignmentDeniedTest < BaseTestCase
  def setup
    @model = new_model do
      state_machine initial: :parked, direct_assignment: :deny do
        event(:ignite) { transition parked: :idling }
      end
    end
  end

  def test_should_deny_direct_assignment
    assert_equal :deny, @model.state_machine.direct_assignment
    assert_raises(StateMachines::DirectStateAssignment) { @model.create!.state = 'idling' }
  end

  def test_should_deny_creating_with_non_initial_state
    assert_raises(StateMachines::DirectStateAssignment) { @model.create!(state: 'idling') }
  end

  def test_should_keep_denying_in_subclasses
    subclass = Class.new(@model) do
      def self.name
        'DeniedVehicleSubclass'
      end

      state_machine { event(:park) { transition idling: :parked } }
    end

    assert_predicate subclass.state_machine, :direct_assignment_denied?
    assert_raises(StateMachines::DirectStateAssignment) { subclass.create!.state = 'idling' }
  end
end

class MachineWithDirectAssignmentGlobalDefaultTest < BaseTestCase
  include DenyDirectAssignment

  def test_should_deny_when_global_default_is_deny
    model = new_model { state_machine(initial: :parked) { state :idling } }

    assert_raises(StateMachines::DirectStateAssignment) { model.create!.state = 'idling' }
  end

  def test_should_let_machine_allow_over_global_deny
    model = new_model { state_machine(initial: :parked, direct_assignment: :allow) { state :idling } }
    record = model.create!
    record.state = 'idling'

    assert record.save
  end
end

class MachineWithDirectAssignmentOnSiblingMachinesTest < BaseTestCase
  def test_should_guard_attribute_when_one_sibling_denies
    model = new_model do
      state_machine initial: :parked, direct_assignment: :deny do
        state :idling
      end
      state_machine :public_state, attribute: :state do
        event(:ignite) { transition parked: :idling }
      end
    end

    assert_raises(StateMachines::DirectStateAssignment) { model.create!.state = 'idling' }
  end
end

class MachineWithInvalidDirectAssignmentTest < BaseTestCase
  def test_should_reject_unknown_mode
    error = assert_raises(ArgumentError) do
      new_model { state_machine(initial: :parked, direct_assignment: :maybe) }
    end

    assert_match(/Invalid direct_assignment: :maybe/, error.message)
  end
end
