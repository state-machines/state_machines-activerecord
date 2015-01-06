require_relative 'test_helper'

class MachineWithDefaultScopeTest < BaseTestCase
  def setup
    @model = new_model
    @machine = StateMachines::Machine.new(@model, :initial => :parked)
    @machine.state :idling

    @model.class_eval do
      default_scope { with_state(:parked, :idling) }
    end
  end

  def test_should_set_initial_state_on_created_object
    object = @model.new
    assert_equal 'parked', object.state
  end
end
