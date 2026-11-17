# frozen_string_literal: true

require_relative 'test_helper'

# An explicit valid? previews the transition (befores, validation); the save
# that follows performs it: the around callbacks wrap the save, which runs
# once, and after callbacks run only when it succeeds.
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

  def test_should_not_enter_the_around_on_valid
    @record.valid?

    assert_empty @log
  end

  def record_ensure(ensured)
    @model.state_machine.around_transition do |_record, _transition, block|
      block.call
    ensure
      ensured << :ensure
    end
  end

  def test_should_propagate_an_exception_from_the_save_through_the_around
    ensured = []
    record_ensure(ensured)
    @model.before_save { raise 'boom' }
    @record.valid?

    assert_raises(RuntimeError, 'boom') { @record.save }
    assert_equal [:ensure], ensured
    refute_includes @log, :after
  end
end

class MachineWithAroundContextValidatedThenSavedTest < BaseTestCase
  def setup
    @model = new_model
    machine = StateMachines::Machine.new(@model, initial: :parked)
    machine.event(:ignite) { transition parked: :idling }
    machine.around_transition { |_record, _transition, block| in_tenant(&block) }
    @record = @model.create!
    @record.state_event = 'ignite'
  end

  def in_tenant
    previous = Fiber[:sm_tenant]
    Fiber[:sm_tenant] = :tenant
    yield
  ensure
    Fiber[:sm_tenant] = previous
  end

  def teardown
    Fiber[:sm_tenant] = nil
  end

  def test_should_keep_the_callers_context
    Fiber[:sm_tenant] = :original
    @record.valid?
    @record.save

    assert_equal :original, Fiber[:sm_tenant]
  end

  def test_should_save_in_the_arounds_context
    seen = nil
    @model.before_save { seen = Fiber[:sm_tenant] }
    @record.valid?
    @record.save

    assert_equal :tenant, seen
  end
end
