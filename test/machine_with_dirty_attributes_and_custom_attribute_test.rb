require_relative 'test_helper'

class MachineWithDirtyAttributesAndCustomAttributeTest < BaseTestCase
  def setup
    @model = new_model do
      connection.add_column table_name, :status, :string
    end
    @machine = StateMachines::Machine.new(@model, :status, :initial => :parked)
    @machine.event :ignite
    @machine.state :idling

    @record = @model.create

    @transition = StateMachines::Transition.new(@record, @machine, :ignite, :parked, :idling)
    @transition.perform(false)
  end

  def test_should_include_state_in_changed_attributes
    assert_equal %w(status), @record.changed
  end

  def test_should_track_attribute_change
    assert_equal %w(parked idling), @record.changes['status']
  end

  def test_should_not_reset_changes_on_multiple_transitions
    transition = StateMachines::Transition.new(@record, @machine, :ignite, :idling, :idling)
    transition.perform(false)

    assert_equal %w(parked idling), @record.changes['status']
  end
end
