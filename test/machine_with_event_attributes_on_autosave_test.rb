require_relative 'test_helper'

class MachineWithEventAttributesOnAutosaveTest < BaseTestCase
  def setup
    @vehicle_model = new_model(:vehicle) do
      connection.add_column table_name, :owner_id, :integer
    end
    MachineWithEventAttributesOnAutosaveTest.const_set('Vehicle', @vehicle_model)

    @owner_model = new_model(:owner)
    MachineWithEventAttributesOnAutosaveTest.const_set('Owner', @owner_model)

    machine = StateMachines::Machine.new(@vehicle_model)
    machine.event :ignite do
      transition :parked => :idling
    end

    @owner = @owner_model.create
    @vehicle = @vehicle_model.create(:state => 'parked', :owner_id => @owner.id)
  end

  def test_should_persist_has_one_autosave
    @owner_model.has_one :vehicle, :class_name => 'MachineWithEventAttributesOnAutosaveTest::Vehicle', :autosave => true
    @owner.vehicle.state_event = 'ignite'
    @owner.save

    @vehicle.reload
    assert_equal 'idling', @vehicle.state
  end

  def test_should_persist_has_many_autosave
    @owner_model.has_many :vehicles, :class_name => 'MachineWithEventAttributesOnAutosaveTest::Vehicle', :autosave => true
    @owner.vehicles[0].state_event = 'ignite'
    @owner.save

    @vehicle.reload
    assert_equal 'idling', @vehicle.state
  end

  def teardown
    MachineWithEventAttributesOnAutosaveTest.class_eval do
      remove_const('Vehicle')
      remove_const('Owner')
    end
    ActiveSupport::Dependencies.clear if defined?(ActiveSupport::Dependencies)
    super
  end
end
