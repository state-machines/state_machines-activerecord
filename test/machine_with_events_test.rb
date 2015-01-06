require_relative 'test_helper'

class MachineWithEventsTest < BaseTestCase
  def setup
    @model = new_model
    @machine = StateMachines::Machine.new(@model)
    @machine.event :shift_up
  end

  def test_should_humanize_name
    assert_equal 'shift up', @machine.event(:shift_up).human_name
  end
end
