require_relative 'test_helper'

class MachineWithStateDrivenValidationsTest < BaseTestCase
  def setup
    @model = new_model do
      attr_accessor :seatbelt
    end

    @machine = StateMachines::Machine.new(@model)
    @machine.state :first_gear, :second_gear do
      validates_presence_of :seatbelt
    end
    @machine.other_states :parked
  end

  def test_should_be_valid_if_validation_fails_outside_state_scope
    record = @model.new(:state => 'parked', :seatbelt => nil)
    assert record.valid?
  end

  def test_should_be_invalid_if_validation_fails_within_state_scope
    record = @model.new(:state => 'first_gear', :seatbelt => nil)
    refute record.valid?
  end

  def test_should_be_valid_if_validation_succeeds_within_state_scope
    record = @model.new(:state => 'second_gear', :seatbelt => true)
    assert record.valid?
  end
end
