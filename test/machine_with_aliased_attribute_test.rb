require_relative 'test_helper'

class MachineWithAliasedAttributeTest < BaseTestCase
  def setup
    @model = new_model do
      alias_attribute :vehicle_status, :state
    end

    @machine = StateMachines::Machine.new(@model, :status, :attribute => :vehicle_status)
    @machine.state :parked

    @record = @model.new
  end

  def test_should_check_custom_attribute_for_predicate
    @record.vehicle_status = nil
    refute @record.status?(:parked)

    @record.vehicle_status = 'parked'
    assert @record.status?(:parked)
  end

  def test_should_initialize_with_original_attribute_names
    record = @model.new(:vehicle_status => 'bogus')
    refute record.status?(:parked)
    assert record.status?(:bogus)
  end
end

