# frozen_string_literal: true

require_relative 'test_helper'

class MachineWithAfterCommitTransitionCallbacksTest < BaseTestCase
  def setup
    @model = new_model do
      attr_reader :callback_log

      def positional_method(transition)
        log_callback(:positional, transition)
      end

      def do_method(transition)
        log_callback(:do, transition)
      end

      def log_callback(name, transition)
        (@callback_log ||= []) << [name, transition.event]
      end
    end
    @machine = StateMachines::Machine.new(@model, initial: :parked)
    @machine.other_states :idling
    @machine.event :ignite do
      transition parked: :idling
    end
  end

  def test_should_run_callback_after_commit
    order = []
    @machine.after_transition { order << :after_transition }
    @machine.after_transition(after_commit: true) { order << :deferred }
    @model.after_commit { order << :model_after_commit }

    record = @model.create

    order.clear
    record.ignite

    assert_equal %i[after_transition model_after_commit deferred], order
  end

  def test_should_defer_callback_until_outer_transaction_commits
    called = false
    @machine.after_transition(after_commit: true) { called = true }

    record = @model.create
    called = false

    @model.transaction do
      record.ignite
      refute called, 'Callback should not run before the outer transaction commits'
    end

    assert called
  end

  def test_should_discard_callback_on_rollback
    called = false
    @machine.after_transition(after_commit: true) { called = true }

    record = @model.create
    called = false

    @model.transaction do
      record.ignite
      raise ActiveRecord::Rollback
    end

    refute called
    assert_equal 'parked', record.reload.state
  end

  def test_should_pass_record_and_transition_to_callback
    callback_args = nil
    @machine.after_transition(after_commit: true) { |*args| callback_args = args }

    record = @model.create
    record.ignite

    object, transition = callback_args
    assert_equal record, object
    assert_instance_of StateMachines::Transition, transition
    assert_equal :ignite, transition.event
    assert_equal 'parked', transition.from
    assert_equal 'idling', transition.to
  end

  def test_should_run_outside_the_transaction
    plain_in_transaction = nil
    deferred_in_transaction = nil
    @machine.after_transition { |object| plain_in_transaction = object.class.connection.transaction_open? }
    @machine.after_transition(after_commit: true) { |object| deferred_in_transaction = object.class.connection.transaction_open? }

    record = @model.create
    record.ignite

    assert plain_in_transaction, 'Plain after_transition should run inside the transaction'
    refute deferred_in_transaction, 'Deferred callback should run after the transaction has committed'
  end

  def test_should_support_do_option_with_method_symbol
    @machine.after_transition(after_commit: true, do: :do_method)

    record = @model.create
    record.ignite

    assert_equal [[:do, :ignite]], record.callback_log
  end

  def test_should_support_positional_method_symbol
    @machine.after_transition(:positional_method, after_commit: true)

    record = @model.create
    record.ignite

    assert_equal [[:positional, :ignite]], record.callback_log
  end

  def test_should_prefer_positional_methods_over_do_option
    # Core's parse_callback_arguments drops :do when positional methods are
    # given; the deferred path must match to avoid double-running side effects
    @machine.after_transition(:positional_method, after_commit: true, do: :do_method)

    record = @model.create
    record.ignite

    assert_equal [[:positional, :ignite]], record.callback_log
  end

  def test_should_bind_block_to_object_when_requested
    callback_self = nil
    callback_args = nil
    @machine.after_transition(after_commit: true, bind_to_object: true) do |*args|
      callback_self = self
      callback_args = args
    end

    record = @model.create
    record.ignite

    assert_equal record, callback_self
    assert_equal 1, callback_args.length
    assert_instance_of StateMachines::Transition, callback_args.first
  end

  def test_should_work_with_global_bind_to_object_default
    original = StateMachines::Callback.bind_to_object
    StateMachines::Callback.bind_to_object = true

    callback_self = nil
    transition_arg = nil
    @machine.after_transition(after_commit: true) do |transition|
      callback_self = self
      transition_arg = transition
    end

    record = @model.create
    record.ignite

    assert_equal record, callback_self
    assert_instance_of StateMachines::Transition, transition_arg
  ensure
    StateMachines::Callback.bind_to_object = original
  end

  def test_should_detect_flag_in_positional_options_hash
    called = false
    @machine.after_transition({ after_commit: true }) { called = true }

    record = @model.create
    called = false

    @model.transaction do
      record.ignite
      refute called
    end

    assert called
  end

  def test_should_respect_branch_requirements
    fired = []
    @machine.state :stalled
    @machine.event :crash do
      transition idling: :stalled
    end
    @machine.after_transition(on: :ignite, after_commit: true) { fired << :ignite_callback }
    @machine.after_transition(on: :crash, after_commit: true) { fired << :crash_callback }

    record = @model.create
    record.ignite

    assert_equal [:ignite_callback], fired

    record.crash

    assert_equal %i[ignite_callback crash_callback], fired
  end

  def test_should_run_immediately_when_no_transaction_is_open
    # With no action, the transition opens no transaction at all, so the
    # callback must execute synchronously via the null transaction
    model = new_model
    machine = StateMachines::Machine.new(model, initial: :parked, action: nil)
    machine.other_states :idling
    machine.event :ignite do
      transition parked: :idling
    end

    called_during_event = false
    machine.after_transition(after_commit: true) do |object|
      called_during_event = true
      refute object.class.connection.transaction_open?
    end

    record = model.create
    record.ignite

    assert called_during_event
  end

  def test_should_not_affect_transition_result
    @machine.after_transition(after_commit: true) { throw :halt }

    record = @model.create

    assert record.ignite
    assert_equal 'idling', record.state
  end

  def test_should_report_exception_and_preserve_committed_state
    subscriber = Class.new do
      attr_reader :errors

      def initialize
        @errors = []
      end

      def report(error, **)
        @errors << error
      end
    end.new
    ActiveSupport.error_reporter.subscribe(subscriber)

    @machine.after_transition(after_commit: true) { raise 'boom' }

    record = @model.create

    assert record.ignite, 'Event should succeed despite the deferred callback raising'
    assert_equal 'idling', record.state, 'In-memory state must not be rolled back'
    assert_equal 'idling', record.reload.state
    assert_equal ['boom'], subscriber.errors.map(&:message)
  ensure
    ActiveSupport.error_reporter.unsubscribe(subscriber)
  end

  def test_should_not_mutate_do_option_array
    do_methods = [:do_method].freeze
    @machine.after_transition(after_commit: true, do: do_methods)

    record = @model.create
    record.ignite

    assert_equal [[:do, :ignite]], record.callback_log
    assert_equal [:do_method], do_methods
  end

  def test_should_match_model_after_commit_semantics_under_non_joinable_wrapper
    # joinable: false wrappers (e.g. transactional test fixtures) are
    # transparent to all of Rails' commit callbacks; ours must behave the same
    fired = []
    @model.after_commit { fired << :model }
    @machine.after_transition(after_commit: true) { fired << :deferred }

    record = @model.create
    fired.clear

    @model.transaction(joinable: false) do
      record.ignite
      raise ActiveRecord::Rollback
    end

    assert_equal %i[model deferred], fired
  end

  def test_should_keep_state_named_after_commit_as_branch_requirement
    fired = []
    @machine.state :after_commit, :done
    @machine.event :finish do
      transition after_commit: :done
    end
    @machine.after_transition(after_commit: :done) { fired << :scoped }

    record = @model.create
    record.ignite

    assert_empty fired, 'Callback scoped to after_commit => done must not fire for parked => idling'

    record.update!(state: 'after_commit')
    record.finish

    assert_equal [:scoped], fired
  end

  def test_should_treat_false_flag_as_regular_callback
    in_transaction = nil
    @machine.after_transition(after_commit: false) { |object| in_transaction = object.class.connection.transaction_open? }

    record = @model.create
    record.ignite

    assert in_transaction, 'after_commit: false should behave as a plain after_transition'
  end

  def test_should_raise_without_methods
    assert_raises(ArgumentError) { @machine.after_transition(after_commit: true) }
  end

  def test_should_not_alter_plain_after_transition
    called = false
    @machine.after_transition { called = true }

    record = @model.create
    called = false

    @model.transaction do
      record.ignite
      assert called, 'Plain after_transition should still run inside the transaction'
    end
  end
end
