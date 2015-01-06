require_relative 'test_helper'

class MachineWithCallbacksTest < BaseTestCase
  def setup
    @model = new_model
    @machine = StateMachines::Machine.new(@model, :initial => :parked)
    @machine.other_states :idling
    @machine.event :ignite

    @record = @model.new(:state => 'parked')
    @transition = StateMachines::Transition.new(@record, @machine, :ignite, :parked, :idling)
  end

  def test_should_run_before_callbacks
    called = false
    @machine.before_transition { called = true }

    @transition.perform
    assert called
  end

  def test_should_pass_record_to_before_callbacks_with_one_argument
    record = nil
    @machine.before_transition { |arg| record = arg }

    @transition.perform
    assert_equal @record, record
  end

  def test_should_pass_record_and_transition_to_before_callbacks_with_multiple_arguments
    callback_args = nil
    @machine.before_transition { |*args| callback_args = args }

    @transition.perform
    assert_equal [@record, @transition], callback_args
  end

  def test_should_run_before_callbacks_outside_the_context_of_the_record
    context = nil
    @machine.before_transition { context = self }

    @transition.perform
    assert_equal self, context
  end

  def test_should_run_after_callbacks
    called = false
    @machine.after_transition { called = true }

    @transition.perform
    assert called
  end

  def test_should_pass_record_to_after_callbacks_with_one_argument
    record = nil
    @machine.after_transition { |arg| record = arg }

    @transition.perform
    assert_equal @record, record
  end

  def test_should_pass_record_and_transition_to_after_callbacks_with_multiple_arguments
    callback_args = nil
    @machine.after_transition { |*args| callback_args = args }

    @transition.perform
    assert_equal [@record, @transition], callback_args
  end

  def test_should_run_after_callbacks_outside_the_context_of_the_record
    context = nil
    @machine.after_transition { context = self }

    @transition.perform
    assert_equal self, context
  end

  def test_should_run_after_callbacks_if_model_callback_added_prior_to_state_machine_definition
    model = new_model do
      after_save { nil }
    end
    machine = StateMachines::Machine.new(model, :initial => :parked)
    machine.other_states :idling
    machine.event :ignite
    after_called = false
    machine.after_transition { after_called = true }

    record = model.new(:state => 'parked')
    transition = StateMachines::Transition.new(record, machine, :ignite, :parked, :idling)
    transition.perform
    assert_equal true, after_called
  end

  def test_should_run_around_callbacks
    before_called = false
    after_called = false
    ensure_called = 0
    @machine.around_transition do |block|
      before_called = true
      begin
        block.call
      ensure
        ensure_called += 1
      end
      after_called = true
    end

    @transition.perform
    assert before_called
    assert after_called
    assert_equal ensure_called, 1
  end

  def test_should_include_transition_states_in_known_states
    @machine.before_transition :to => :first_gear, :do => lambda {}

    assert_equal [:parked, :idling, :first_gear], @machine.states.map { |state| state.name }
  end

  def test_should_allow_symbolic_callbacks
    callback_args = nil

    klass = class << @record;
      self;
    end
    klass.send(:define_method, :after_ignite) do |*args|
      callback_args = args
    end

    @machine.before_transition(:after_ignite)

    @transition.perform
    assert_equal [@transition], callback_args
  end

  def test_should_allow_string_callbacks
    class << @record
      attr_reader :callback_result
    end

    @machine.before_transition('@callback_result = [1, 2, 3]')
    @transition.perform

    assert_equal [1, 2, 3], @record.callback_result
  end

  def test_should_run_in_expected_order
    expected = [
        :before_transition, :before_validation, :after_validation,
        :before_save, :before_create, :after_create, :after_save,
        :after_transition
    ]

    callbacks = []
    @model.before_validation { callbacks << :before_validation }
    @model.after_validation { callbacks << :after_validation }
    @model.before_save { callbacks << :before_save }
    @model.before_create { callbacks << :before_create }
    @model.after_create { callbacks << :after_create }
    @model.after_save { callbacks << :after_save }
    @model.after_commit { callbacks << :after_commit }
    expected << :after_commit

    @machine.before_transition { callbacks << :before_transition }
    @machine.after_transition { callbacks << :after_transition }

    @transition.perform

    assert_equal expected, callbacks
  end
end

