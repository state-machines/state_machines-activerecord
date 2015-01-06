require_relative 'test_helper'

class MachineWithConflictingPredicateTest < BaseTestCase
  def setup
    @model = new_model do
      def state?(*args)
        true
      end
    end

    @machine = StateMachines::Machine.new(@model)
    @record = @model.new
  end

  def test_should_not_define_attribute_predicate
    assert @record.state?
  end
end
