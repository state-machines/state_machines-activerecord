require_relative 'test_helper'

class MachineWithEventAttributesOnSaveBangTest < BaseTestCase
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
    assert_raise(ActiveRecord::RecordInvalid) { @record.save! }
  end

  def test_should_fail_if_event_has_no_transition
    @record.state = 'idling'
    assert_raise(ActiveRecord::RecordInvalid) { @record.save! }
  end

  def test_should_be_successful_if_event_has_transition
    assert_equal true, @record.save!
  end

  def test_should_run_before_callbacks
    ran_callback = false
    @machine.before_transition { ran_callback = true }

    @record.save!
    assert ran_callback
  end

  def test_should_run_before_callbacks_once
    before_count = 0
    @machine.before_transition { before_count += 1 }

    @record.save!
    assert_equal 1, before_count
  end

  def test_should_run_around_callbacks_before_yield
    ran_callback = false
    @machine.around_transition { |block| ran_callback = true; block.call }

    @record.save!
    assert ran_callback
  end

  def test_should_run_around_callbacks_before_yield_once
    around_before_count = 0
    @machine.around_transition { |block| around_before_count += 1; block.call }

    @record.save!
    assert_equal 1, around_before_count
  end

  def test_should_persist_new_state
    @record.save!
    assert_equal 'idling', @record.state
  end

  def test_should_run_after_callbacks
    ran_callback = false
    @machine.after_transition { ran_callback = true }

    @record.save!
    assert ran_callback
  end

  def test_should_run_around_callbacks_after_yield
    ran_callback = false
    @machine.around_transition { |block| block.call; ran_callback = true }

    @record.save!
    assert ran_callback
  end
end
