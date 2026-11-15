# frozen_string_literal: true

require_relative 'test_helper'

module ForceStateHelpers
  private

  def vehicle_model(direct_assignment)
    new_model do
      connection.add_column table_name, :name, :string
      attr_accessor :transitions_run, :saves_run

      before_save { self.saves_run = (saves_run || 0) + 1 }

      state_machine initial: :parked, direct_assignment: direct_assignment do
        after_transition { |record| record.transitions_run = (record.transitions_run || 0) + 1 }

        event(:ignite) { transition parked: :idling }
        state :stalled
      end
    end
  end
end

class MachineWithForceStateOnDeniedMachineTest < BaseTestCase
  include ForceStateHelpers

  def setup
    @model = vehicle_model(:deny)
    @record = @model.create!
    @record.saves_run = 0
  end

  def test_should_persist_forced_state
    assert @record.force_state!(:stalled)
    assert_equal 'stalled', @record.reload.state
  end

  def test_should_run_save_callbacks_but_no_transition_callbacks
    @record.force_state!(:stalled)

    assert_equal 1, @record.saves_run
    assert_nil @record.transitions_run
  end

  def test_should_accept_state_name_as_string
    @record.force_state!('stalled')

    assert_equal 'stalled', @record.reload.state
  end

  def test_should_still_deny_direct_assignment_afterwards
    @record.force_state!(:stalled)

    assert_raises(StateMachines::DirectStateAssignment) { @record.state = 'idling' }
  end

  def test_should_refuse_unknown_state
    assert_raises(IndexError) { @record.force_state!(:flying) }
    assert_equal 'parked', @record.state
    refute_predicate @record, :changed?
  end

  def test_should_refuse_while_an_event_is_queued
    @record.state_event = 'ignite'

    error = assert_raises(StateMachines::PendingStateEvent) { @record.force_state!(:stalled) }
    assert_match(/Cannot call force_state! on/, error.message)
    assert_equal 'parked', @record.state
  end
end

class MachineWithForceStateOnAllowedMachineTest < BaseTestCase
  include ForceStateHelpers

  def test_should_force_state_on_allowing_machine
    model = vehicle_model(:allow)
    record = model.create!
    record.force_state!(:stalled)

    assert_equal 'stalled', record.reload.state
    assert_nil record.transitions_run
  end
end

class MachineWithForceStateOnInvalidRecordTest < BaseTestCase
  def test_should_raise_record_invalid
    model = new_model do
      connection.add_column table_name, :name, :string
      validates :name, presence: true, on: :update

      state_machine(initial: :parked, direct_assignment: :deny) { state :stalled }
    end
    record = model.create!

    assert_raises(ActiveRecord::RecordInvalid) { record.force_state!(:stalled) }
    assert_equal 'parked', record.reload.state
  end
end

class MachineWithForceStateOnMultipleMachinesTest < BaseTestCase
  def setup
    @model = new_model do
      connection.add_column table_name, :alarm_state, :string
      state_machine(initial: :parked, direct_assignment: :deny) { state :stalled }
      state_machine(:alarm_state, initial: :active, direct_assignment: :deny) { state :off }
    end
    @record = @model.create!
  end

  def test_should_require_machine_name
    error = assert_raises(ArgumentError) { @record.force_state!(:off) }
    assert_match(/several state machines \(:state, :alarm_state\); pass machine:/, error.message)
  end

  def test_should_force_named_machine
    @record.force_state!(:off, machine: :alarm_state)
    @record.reload

    assert_equal %w[parked off], [@record.state, @record.alarm_state]
  end

  def test_should_refuse_unknown_machine
    error = assert_raises(ArgumentError) { @record.force_state!(:off, machine: :engine) }
    assert_match(/has no state machine :engine/, error.message)
  end
end
