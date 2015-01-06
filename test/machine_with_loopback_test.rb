require_relative 'test_helper'

class MachineWithLoopbackTest < BaseTestCase
  def setup
    @model = new_model do
      connection.add_column table_name, :updated_at, :datetime
    end

    @machine = StateMachines::Machine.new(@model, :initial => :parked)
    @machine.event :park

    @record = @model.create(:updated_at => Time.now - 1)
    @transition = StateMachines::Transition.new(@record, @machine, :park, :parked, :parked)

    @timestamp = @record.updated_at
    @transition.perform
  end

  def test_should_not_update_record
    assert_equal @timestamp, @record.updated_at
  end
end
