require_relative 'test_helper'

class MachineWithEventAttributesOnValidationTest < BaseTestCase
  def setup
    @model = new_model
    @machine = StateMachines::Machine.new(@model)
    @machine.event :ignite do
      transition :parked => :idling
    end

    @record = @model.new
    @record.state = 'parked'
    @record.state_event = 'ignite'
  end

  def test_should_fail_if_event_is_invalid
    @record.state_event = 'invalid'
    refute @record.valid?
    assert_equal ['State event is invalid'], @record.errors.full_messages
  end

  def test_should_fail_if_event_has_no_transition
    @record.state = 'idling'
    refute @record.valid?
    assert_equal ['State event cannot transition when idling'], @record.errors.full_messages
  end

  def test_should_be_successful_if_event_has_transition
    assert @record.valid?
  end

  def test_should_run_before_callbacks
    ran_callback = false
    @machine.before_transition { ran_callback = true }

    @record.valid?
    assert ran_callback
  end

  def test_should_run_around_callbacks_before_yield
    ran_callback = false
    @machine.around_transition { |block| ran_callback = true; block.call }

    begin
      @record.valid?
    rescue ArgumentError
      raise if StateMachines::Transition.pause_supported?
    end
    assert ran_callback
  end

  def test_should_persist_new_state
    @record.valid?
    assert_equal 'idling', @record.state
  end

  def test_should_not_run_after_callbacks
    ran_callback = false
    @machine.after_transition { ran_callback = true }

    @record.valid?
    refute ran_callback
  end

  def test_should_not_run_after_callbacks_with_failures_disabled_if_validation_fails
    @model.class_eval do
      attr_accessor :seatbelt
      validates_presence_of :seatbelt
    end

    ran_callback = false
    @machine.after_transition { ran_callback = true }

    @record.valid?
    refute ran_callback
  end

  def test_should_run_after_callbacks_if_validation_fails
    @model.class_eval do
      attr_accessor :seatbelt
      validates_presence_of :seatbelt
    end

    ran_callback = false
    @machine.after_failure { ran_callback = true }

    @record.valid?
    assert ran_callback
  end

  def test_should_not_run_around_callbacks_after_yield
    ran_callback = false
    @machine.around_transition { |block| block.call; ran_callback = true }

    begin
      @record.valid?
    rescue ArgumentError
      raise if StateMachines::Transition.pause_supported?
    end
    refute ran_callback
  end

  def test_should_not_run_around_callbacks_after_yield_with_failures_disabled_if_validation_fails
    @model.class_eval do
      attr_accessor :seatbelt
      validates_presence_of :seatbelt
    end

    ran_callback = false
    @machine.around_transition { |block| block.call; ran_callback = true }

    @record.valid?
    refute ran_callback
  end

  def test_should_rollback_before_transitions_with_raise
    @machine.before_transition {
      @model.create;
      raise ActiveRecord::Rollback
    }

    begin
      @record.valid?
    rescue Exception
    end

    assert_equal 0, @model.count
  end

  def test_should_rollback_before_transitions_with_false
    @machine.before_transition {
      @model.create;
      false
    }

    begin
      @record.valid?
    rescue Exception
    end

    assert_equal 0, @model.count
  end
end
