require_relative 'test_helper'

class MachineWithInitializedAliasedAttributeTest < BaseTestCase
  def setup
    @model = new_model do
      alias_attribute :custom_status, :state
    end

    @machine = StateMachines::Machine.new(@model, :initial => :parked, :attribute => :state)
    @machine.state :started

    @record = @model.new(:custom_status => :started)
  end

  def test_should_match_original_attribute_value
    refute @record.state?(:parked)
    assert @record.state?(:started)
  end
end

