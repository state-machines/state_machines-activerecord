require_relative 'test_helper'

class MachineUnmigratedTest < BaseTestCase
  def setup
    @model = new_model(false)

    # Drop the table so that it definitely doesn't exist
    @model.connection.drop_table(@model.table_name) if @model.table_exists?
  end

  def test_should_allow_machine_creation
    assert_nothing_raised { StateMachines::Machine.new(@model) }
  end
end