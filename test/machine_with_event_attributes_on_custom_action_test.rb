require_relative 'test_helper'

class MachineWithEventAttributesOnCustomActionTest < BaseTestCase
  def setup
    @superclass = new_model do
      def persist
        create_or_update
      end
    end
    @model = Class.new(@superclass)
    @machine = StateMachines::Machine.new(@model, :action => :persist)
    @machine.event :ignite do
      transition :parked => :idling
    end

    @record = @model.new
    @record.state = 'parked'
    @record.state_event = 'ignite'
  end

  def test_should_not_transition_on_valid?
    @record.valid?
    assert_equal 'parked', @record.state
  end

  def test_should_not_transition_on_save
    @record.save
    assert_equal 'parked', @record.state
  end

  def test_should_not_transition_on_save!
    @record.save!
    assert_equal 'parked', @record.state
  end

  def test_should_transition_on_custom_action
    @record.persist
    assert_equal 'idling', @record.state
  end
end

