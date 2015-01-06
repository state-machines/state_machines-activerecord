require_relative 'test_helper'

class MachineWithScopesAndOwnerSubclassTest < BaseTestCase
  def setup
    @model = new_model
    @machine = StateMachines::Machine.new(@model, :state)

    @subclass = Class.new(@model)
    @subclass_machine = @subclass.state_machine(:state) {}
    @subclass_machine.state :parked, :idling, :first_gear
  end

  def test_should_only_include_records_with_subclass_states_in_with_scope
    parked = @subclass.create :state => 'parked'
    idling = @subclass.create :state => 'idling'

    assert_equal [parked, idling], @subclass.with_states(:parked, :idling).all
  end

  def test_should_only_include_records_without_subclass_states_in_without_scope
    parked = @subclass.create :state => 'parked'
    idling = @subclass.create :state => 'idling'
    first_gear = @subclass.create :state => 'first_gear'

    assert_equal [parked, idling], @subclass.without_states(:first_gear).all
  end
end
