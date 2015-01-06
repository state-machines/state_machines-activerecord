require_relative 'test_helper'

class MachineWithFailedBeforeCallbacksTest < BaseTestCase
  def setup
    @callbacks = []

    @model = new_model
    @machine = StateMachines::Machine.new(@model)
    @machine.state :parked, :idling
    @machine.event :ignite
    @machine.before_transition { @callbacks << :before_1; false }
    @machine.before_transition { @callbacks << :before_2 }
    @machine.after_transition { @callbacks << :after }
    @machine.around_transition { |block| @callbacks << :around_before; block.call; @callbacks << :around_after }

    @record = @model.new(:state => 'parked')
    @transition = StateMachines::Transition.new(@record, @machine, :ignite, :parked, :idling)
    @result = @transition.perform
  end

  def test_should_not_be_successful
    refute @result
  end

  def test_should_not_change_current_state
    assert_equal 'parked', @record.state
  end

  def test_should_not_run_action
    assert @record.new_record?
  end

  def test_should_not_run_further_callbacks
    assert_equal [:before_1], @callbacks
  end
end
