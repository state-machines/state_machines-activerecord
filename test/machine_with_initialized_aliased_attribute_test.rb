require_relative 'test_helper'

class MachineWithInitializedAliasedAttributeTest < BaseTestCase
  def setup
    @model = new_model do
      alias_attribute :custom_status, :state
    end

    @machine = StateMachines::Machine.new(@model, :initial => :parked, :attribute => :state)
    @machine.state :started

    @record = @model.new(:custom_status => :parked)
  end

  def test_should_match_original_attribute_value
    assert @record.state?(:parked)
    refute @record.state?(:started)
  end

  def test_should_refuse_non_initial_state_through_alias
    assert_raises(StateMachines::DirectStateAssignment) { @model.new(:custom_status => :started) }
  end
end

