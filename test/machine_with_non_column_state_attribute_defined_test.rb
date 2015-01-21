require_relative 'test_helper'

class MachineWithNonColumnStateAttributeDefinedTest < BaseTestCase
  def setup
    @model = new_model do
      attr_accessor :status
    end

    @machine = StateMachines::Machine.new(@model, :status, :initial => :parked)
    @machine.other_states(:idling)
    @record = @model.new
  end

  def test_should_return_false_for_predicate_if_does_not_match_current_value
    refute @record.status?(:idling)
  end

  def test_should_return_true_for_predicate_if_matches_current_value
    assert @record.status?(:parked)
  end

  def test_should_raise_exception_for_predicate_if_invalid_state_specified
    assert_raise(IndexError) { @record.status?(:invalid) }
  end

  def test_should_set_initial_state_on_created_object
    assert_equal 'parked', @record.status
  end
end
