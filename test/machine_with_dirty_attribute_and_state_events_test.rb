require_relative 'test_helper'

class MachineWithDirtyAttributeAndStateEventsTest < BaseTestCase
  def setup
    @model = new_model
    @machine = StateMachines::Machine.new(@model, :initial => :parked)
    @machine.event :ignite

    @record = @model.create
    @record.state_event = 'ignite'
  end

  def test_should_not_include_state_in_changed_attributes
    assert_equal [], @record.changed
  end

  def test_should_not_track_attribute_change
    assert_equal nil, @record.changes['state']
  end
end
