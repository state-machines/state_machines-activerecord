# frozen_string_literal: true

require_relative 'test_helper'

# An explicit valid? runs the before callbacks and pauses the arounds; the
# save that follows must run the action once, finish the arounds with its
# outcome, and run after callbacks only when the save succeeds.
class MachineWithEventAttributesValidatedThenSavedTest < BaseTestCase
  def setup
    @log = []
    @model = new_model do
      attr_accessor :fail_save

      before_save { throw :abort if fail_save }
    end
    machine = StateMachines::Machine.new(@model, initial: :parked)
    machine.event(:ignite) { transition parked: :idling }
    @record = @model.create!
    log_callbacks(machine)
    @record.state_event = 'ignite'
  end

  def log_callbacks(machine)
    log = @log
    machine.around_transition do |_record, _transition, block|
      log << :around_in
      block.call
      log << :around_out
    end
    machine.after_transition { log << :after }
    machine.after_failure { log << :failure }
  end

  def test_should_save_after_an_explicit_valid
    assert @record.valid?
    assert @record.save
    assert_equal 'idling', @record.reload.state
  end

  def test_should_finish_the_around_after_the_save
    @record.valid?
    @record.save

    assert_equal %i[around_in around_out after], @log
  end

  def test_should_not_run_afters_when_the_save_fails
    @record.fail_save = true
    @record.valid?

    refute @record.save
    assert_equal 'parked', @record.reload.state
    assert_equal %i[around_in failure], @log
  end
end
