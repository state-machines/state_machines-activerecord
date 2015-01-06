require_relative 'test_helper'

class MachineWithDirtyAttributeAndCustomAttributesDuringLoopbackTest < BaseTestCase
  def setup
    @model = new_model do
      connection.add_column table_name, :status, :string
    end
    @machine = StateMachines::Machine.new(@model, :status, :initial => :parked)
    @machine.event :park

    @record = @model.create

    @transition = StateMachines::Transition.new(@record, @machine, :park, :parked, :parked)
    @transition.perform(false)
  end

  def test_should_not_include_state_in_changed_attributes
    assert_equal [], @record.changed
  end

  def test_should_not_track_attribute_changes
    assert_equal nil, @record.changes['status']
  end
end
