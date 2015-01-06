require_relative 'test_helper'

class MachineErrorsTest < BaseTestCase
  def setup
    @model = new_model
    @machine = StateMachines::Machine.new(@model)
    @record = @model.new
  end

  def test_should_be_able_to_describe_current_errors
    @record.errors.add(:id, 'cannot be blank')
    @record.errors.add(:state, 'is invalid')
    assert_equal ['Id cannot be blank', 'State is invalid'], @machine.errors_for(@record).split(', ').sort
  end

  def test_should_describe_as_halted_with_no_errors
    assert_equal 'Transition halted', @machine.errors_for(@record)
  end
end
