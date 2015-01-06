require_relative 'test_helper'

class MachineWithNonColumnStateAttributeUndefinedTest < BaseTestCase
  def setup
    @model = new_model do
      def initialize
        # Skip attribute initialization
        @initialized_state_machines = true
        super
      end
    end

    @machine = StateMachines::Machine.new(@model, :status, :initial => :parked)
    @machine.other_states(:idling)
    @record = @model.new
  end

  def test_should_not_define_a_column_for_the_attribute
    assert_nil @model.columns_hash['status']
  end

  def test_should_define_a_reader_attribute_for_the_attribute
    assert @record.respond_to?(:status)
  end

  def test_should_define_a_writer_attribute_for_the_attribute
    assert @record.respond_to?(:status=)
  end

  def test_should_define_an_attribute_predicate
    assert @record.respond_to?(:status?)
  end
end
