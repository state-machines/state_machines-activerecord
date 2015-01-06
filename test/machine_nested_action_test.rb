require_relative 'test_helper'

class MachineNestedActionTest < BaseTestCase
  def setup
    @callbacks = []

    @model = new_model
    @machine = StateMachines::Machine.new(@model)
    @machine.event :ignite do
      transition :parked => :idling
    end

    @record = @model.new(:state => 'parked')
  end

  def test_should_allow_transition_prior_to_creation_if_skipping_action
    record = @record
    @model.before_create { record.ignite(false) }
    result = @record.save

    assert_equal true, result
    assert_equal "idling", @record.state
    @record.reload
    assert_equal "idling", @record.state
  end

  def test_should_allow_transition_after_creation
    record = @record
    @model.after_create { record.ignite }
    result = @record.save

    assert_equal true, result
    assert_equal "idling", @record.state
    @record.reload
    assert_equal "idling", @record.state
  end
end

