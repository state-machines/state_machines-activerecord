# frozen_string_literal: true

require_relative 'test_helper'

# When the second machine's before callback halts, both machines' transitions
# fail and run their failure callbacks, on valid? as on save
class MachineMultipleWithHaltingEventTest < BaseTestCase
  def setup
    @log = []
    @model = new_model { connection.add_column table_name, :status, :string }
    add_machine(:state, :parked, :idling, name: :first)
    add_machine(:status, :off, :on, name: :second, halt: true)
    @record = @model.create!
    @record.state_event = 'go'
    @record.status_event = 'go'
  end

  def add_machine(attribute, from, to, name:, halt: false)
    log = @log
    machine = StateMachines::Machine.new(@model, attribute, initial: from)
    machine.event(:go) { transition from => to }
    machine.before_transition do
      log << name
      throw :halt if halt
    end
    machine.after_failure { log << :"#{name}_failure" }
  end

  def test_should_fail_both_machines_on_save
    refute @record.save
    assert_equal %i[first second second_failure first_failure], @log
  end

  def test_should_fail_both_machines_on_valid
    refute @record.valid?
    assert_equal %i[first second second_failure first_failure], @log
  end
end
