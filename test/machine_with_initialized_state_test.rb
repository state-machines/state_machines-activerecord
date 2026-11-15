# frozen_string_literal: true

require_relative 'test_helper'

# Building a record with a state other than its initial state is a direct
# state assignment: there is no new-record loophole.
class MachineWithInitializedStateTest < BaseTestCase
  def setup
    @model = new_model
    @machine = StateMachines::Machine.new(@model, initial: :parked, direct_assignment: :deny)
    @machine.state :idling
  end

  def test_should_allow_initial_state_when_static
    record = @model.new(state: 'parked')
    assert_equal 'parked', record.state
  end

  def test_should_allow_initial_state_when_dynamic
    @machine.initial_state = -> { :parked }
    record = @model.new(state: 'parked')
    assert_equal 'parked', record.state
  end

  def test_should_refuse_nil_state_when_static
    @machine.state nil

    assert_raises(StateMachines::DirectStateAssignment) { @model.new(state: nil) }
  end

  def test_should_refuse_nil_state_when_dynamic
    @machine.state nil

    @machine.initial_state = -> { :parked }
    assert_raises(StateMachines::DirectStateAssignment) { @model.new(state: nil) }
  end

  def test_should_refuse_different_initial_state_when_static
    assert_raises(StateMachines::DirectStateAssignment) { @model.new(state: 'idling') }
  end

  def test_should_refuse_different_initial_state_when_using_create_with
    assert_raises(StateMachines::DirectStateAssignment) { @model.create_with(state: 'idling').new }
  end

  def test_should_allow_initial_state_when_using_create_with
    assert_equal 'parked', @model.create_with(state: 'parked').new.state
  end

  def test_should_refuse_different_initial_state_when_dynamic
    @machine.initial_state = -> { :parked }
    assert_raises(StateMachines::DirectStateAssignment) { @model.new(state: 'idling') }
  end
end
