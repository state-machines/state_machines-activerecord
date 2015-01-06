require_relative 'test_helper'

class MachineWithFailedActionTest < BaseTestCase
  def setup
    @model = new_model do
      validates_inclusion_of :state, :in => %w(first_gear)
    end

    @machine = StateMachines::Machine.new(@model)
    @machine.state :parked, :idling
    @machine.event :ignite

    @callbacks = []
    @machine.before_transition { @callbacks << :before }
    @machine.after_transition { @callbacks << :after }
    @machine.after_failure { @callbacks << :after_failure }
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

  def test_should_not_save_record
    assert @record.new_record?
  end

  def test_should_run_before_callbacks_and_after_callbacks_with_failures
    assert_equal [:before, :around_before, :after_failure], @callbacks
  end
end

