require_relative 'test_helper'

class MachineWithScopesAndJoinsTest < BaseTestCase
  def setup
    @company = new_model(:company)
    MachineWithScopesAndJoinsTest.const_set('Company', @company)

    @vehicle = new_model(:vehicle) do
      connection.add_column table_name, :company_id, :integer
      belongs_to :company, :class_name => 'MachineWithScopesAndJoinsTest::Company'
    end
    MachineWithScopesAndJoinsTest.const_set('Vehicle', @vehicle)

    @company_machine = StateMachines::Machine.new(@company, :initial => :active)
    @vehicle_machine = StateMachines::Machine.new(@vehicle, :initial => :parked)
    @vehicle_machine.state :idling

    @ford = @company.create
    @mustang = @vehicle.create(:company => @ford)
  end

  def test_should_find_records_in_with_scope
    assert_equal [@mustang], @vehicle.with_states(:parked).joins(:company).where("#{@company.table_name}.state = \"active\"")
  end

  def test_should_find_records_in_without_scope
    assert_equal [@mustang], @vehicle.without_states(:idling).joins(:company).where("#{@company.table_name}.state = \"active\"")
  end

  def teardown
    MachineWithScopesAndJoinsTest.class_eval do
      remove_const('Vehicle')
      remove_const('Company')
    end
    ActiveSupport::Dependencies.clear
  end
end
