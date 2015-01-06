require_relative 'test_helper'

class MachineWithFailedAfterCallbacksTest < BaseTestCase
  def setup
    @callbacks = []

    @model = new_model
    @machine = StateMachines::Machine.new(@model)
    @machine.state :parked, :idling
    @machine.event :ignite
    @machine.after_transition { @callbacks << :after_1; false }
    @machine.after_transition { @callbacks << :after_2 }
    @machine.around_transition { |block| @callbacks << :around_before; block.call; @callbacks << :around_after }

    @record = @model.new(:state => 'parked')
    @transition = StateMachines::Transition.new(@record, @machine, :ignite, :parked, :idling)
    @result = @transition.perform
  end

  def test_should_be_successful
    assert @result
  end

  def test_should_change_current_state
    assert_equal 'idling', @record.state
  end

  def test_should_save_record
    refute @record.new_record?
  end

  def test_should_not_run_further_after_callbacks
    assert_equal [:around_before, :around_after, :after_1], @callbacks
  end
end
