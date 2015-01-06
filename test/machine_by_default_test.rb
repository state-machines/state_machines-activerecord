require_relative 'test_helper'

class MachineByDefaultTest < BaseTestCase
  def setup
    @model = new_model
    @machine = StateMachines::Machine.new(@model)
  end

  def test_should_use_save_as_action
    assert_equal :save, @machine.action
  end

  def test_should_use_transactions
    assert_equal true, @machine.use_transactions
  end
end
