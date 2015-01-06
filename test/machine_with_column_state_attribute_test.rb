require_relative 'test_helper'

class MachineWithColumnStateAttributeTest < BaseTestCase
  def setup
    @model = new_model
    @machine = StateMachines::Machine.new(@model, :initial => :parked)
    @machine.other_states(:idling)

    @record = @model.new
  end

  def test_should_not_override_the_column_reader
    @record[:state] = 'parked'
    assert_equal 'parked', @record.state
  end

  def test_should_not_override_the_column_writer
    @record.state = 'parked'
    assert_equal 'parked', @record[:state]
  end

  def test_should_have_an_attribute_predicate
    assert @record.respond_to?(:state?)
  end

  def test_should_test_for_existence_on_predicate_without_parameters
    assert @record.state?

    @record.state = nil
    refute @record.state?
  end

  def test_should_return_false_for_predicate_if_does_not_match_current_value
    refute @record.state?(:idling)
  end

  def test_should_return_true_for_predicate_if_matches_current_value
    assert @record.state?(:parked)
  end

  def test_should_raise_exception_for_predicate_if_invalid_state_specified
    assert_raises(IndexError) { @record.state?(:invalid) }
  end
end
