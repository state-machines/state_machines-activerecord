require_relative 'test_helper'

class MachineMultipleTest < BaseTestCase
  def setup
    @model = new_model do
      connection.add_column table_name, :status, :string
    end
    @state_machine = StateMachines::Machine.new(@model, :initial => :parked)
    @status_machine = StateMachines::Machine.new(@model, :status, :initial => :idling)
  end

  def test_should_should_initialize_each_state
    record = @model.new
    assert_equal 'parked', record.state
    assert_equal 'idling', record.status
  end
end
