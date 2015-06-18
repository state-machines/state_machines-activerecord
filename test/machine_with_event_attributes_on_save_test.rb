require_relative 'test_helper'

class MachineWithEventAttributesOnSaveTest < BaseTestCase
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
    assert_equal false, @record.save
  end

  def test_should_fail_if_event_has_no_transition
    @record.state = 'idling'
    assert_equal false, @record.save
  end

  def test_should_run_before_callbacks
    ran_callback = false
    @machine.before_transition { ran_callback = true }

    @record.save
    assert ran_callback
  end

  def test_should_run_before_callbacks_once
    before_count = 0
    @machine.before_transition { before_count += 1 }

    @record.save
    assert_equal 1, before_count
  end

  def test_should_run_around_callbacks_before_yield
    ran_callback = false
    @machine.around_transition { |block| ran_callback = true; block.call }

    @record.save
    assert ran_callback
  end

  def test_should_run_around_callbacks_before_yield_once
    around_before_count = 0
    @machine.around_transition { |block| around_before_count += 1; block.call }

    @record.save
    assert_equal 1, around_before_count
  end

  def test_should_persist_new_state
    @record.save
    assert_equal 'idling', @record.state
  end

  def test_should_run_after_callbacks
    ran_callback = false
    @machine.after_transition { ran_callback = true }

    @record.save
    assert ran_callback
  end

  def test_should_not_run_after_callbacks_with_failures_disabled_if_fails
    @model.before_create { |record| false }

    ran_callback = false
    @machine.after_transition { ran_callback = true }

    begin
      ; @record.save;
    rescue;
    end
    refute ran_callback
  end

  def test_should_run_failure_callbacks__if_fails
    @model.before_create { |record| false }

    ran_callback = false
    @machine.after_failure { ran_callback = true }

    begin
      ; @record.save;
    rescue;
    end
    assert ran_callback
  end

  def test_should_not_run_around_callbacks_if_fails
    @model.before_create { |record| false }

    ran_callback = false
    @machine.around_transition { |block| block.call; ran_callback = true }

    begin
      ; @record.save;
    rescue;
    end
    refute ran_callback
  end

  def test_should_run_around_callbacks_after_yield
    ran_callback = false
    @machine.around_transition { |block| block.call; ran_callback = true }

    @record.save
    assert ran_callback
  end

  def test_should_run_before_transitions_within_transaction
    @machine.before_transition { @model.create; raise ActiveRecord::Rollback }

    begin
      @record.save
    rescue Exception
    end

    assert_equal 0, @model.count
  end

  def test_should_run_after_transitions_within_transaction
    @machine.after_transition { @model.create; raise ActiveRecord::Rollback }

    begin
      @record.save
    rescue Exception
    end

    assert_equal 0, @model.count
  end

  def test_should_run_around_transition_within_transaction
    @machine.around_transition { @model.create; raise ActiveRecord::Rollback }

    begin
      @record.save
    rescue Exception
    end

    assert_equal 0, @model.count
  end

  def test_should_allow_additional_transitions_to_new_state_in_after_transitions
    @machine.event :park do
      transition :idling => :parked
    end

    @machine.after_transition(:on => :ignite) { @record.park }

    @record.save
    assert_equal 'parked', @record.state

    @record.reload
    assert_equal 'parked', @record.state
  end

  def test_should_allow_additional_transitions_to_previous_state_in_after_transitions
    @machine.event :shift_up do
      transition :idling => :first_gear
    end

    @machine.after_transition(:on => :ignite) { @record.shift_up }

    @record.save
    assert_equal 'first_gear', @record.state

    @record.reload
    assert_equal 'first_gear', @record.state
  end

  def test_should_yield_one_model!
    assert_equal true, @record.save!
    assert_equal 1, @model.count
  end

  # explicit tests of #save and #save! to ensure expected behavior
  def test_should_yield_two_models_with_before
    @machine.before_transition { @model.create! }
    assert_equal true, @record.save
    assert_equal 2, @model.count
  end

  def test_should_yield_two_models_with_before!
    @machine.before_transition { @model.create! }
    assert_equal true, @record.save!
    assert_equal 2, @model.count
  end

  def test_should_raise_on_around_transition_rollback!
    @machine.before_transition { @model.create! }
    @machine.around_transition { @model.create!; raise ActiveRecord::Rollback }

    raised = false
    begin
      @record.save!
    rescue Exception
      raised = true
    end

    assert_equal true, raised
    assert_equal 0, @model.count
  end

  def test_should_return_nil_on_around_transition_rollback
    @machine.before_transition { @model.create! }
    @machine.around_transition { @model.create!; raise ActiveRecord::Rollback }
    assert_equal nil, @record.save
    assert_equal 0, @model.count
  end

  def test_should_return_nil_on_before_transition_rollback
    @machine.before_transition { raise ActiveRecord::Rollback }
    assert_equal nil, @record.save
    assert_equal 0, @model.count
  end

  #
  # @rosskevin - This fails and I'm not sure why, it was existing behavior.
  #   see: https://github.com/state-machines/state_machines-activerecord/pull/26#issuecomment-112911886
  #
  # def test_should_yield_three_models_with_before_and_around_save
  #   @machine.before_transition { @model.create!; puts "before ran, now #{@model.count}" }
  #   @machine.around_transition { @model.create!; puts "around ran, now #{@model.count}" }
  #
  #   assert_equal true, @record.save
  #   assert_equal 3, @model.count
  # end
  #
  # def test_should_yield_three_models_with_before_and_around_save!
  #   @machine.before_transition { @model.create!; puts "before ran, now #{@model.count}" }
  #   @machine.around_transition { @model.create!; puts "around ran, now #{@model.count}" }
  #
  #   assert_equal true, @record.save!
  #   assert_equal 3, @model.count
  # end
end
