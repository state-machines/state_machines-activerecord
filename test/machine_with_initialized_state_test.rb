require_relative 'test_helper'

class MachineWithInitializedStateTest < BaseTestCase
  def setup
    @model = new_model
    @machine = StateMachines::Machine.new(@model, :initial => :parked)
    @machine.state :idling
  end

  def test_should_allow_nil_initial_state_when_static
    @machine.state nil

    record = @model.new(:state => nil)
    assert_nil record.state
  end

  def test_should_allow_nil_initial_state_when_dynamic
    @machine.state nil

    @machine.initial_state = lambda { :parked }
    record = @model.new(:state => nil)
    assert_nil record.state
  end

  def test_should_allow_different_initial_state_when_static
    record = @model.new(:state => 'idling')
    assert_equal 'idling', record.state
  end

  def test_should_allow_different_initial_state_when_dynamic
    @machine.initial_state = lambda { :parked }
    record = @model.new(:state => 'idling')
    assert_equal 'idling', record.state
  end
end
