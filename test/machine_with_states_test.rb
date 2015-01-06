require_relative 'test_helper'

class MachineWithStatesTest < BaseTestCase
  def setup
    @model = new_model
    @machine = StateMachines::Machine.new(@model)
    @machine.state :first_gear
  end

  def test_should_humanize_name
    assert_equal 'first gear', @machine.state(:first_gear).human_name
  end
end
