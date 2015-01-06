require_relative 'test_helper'

class MachineWithTransactionsTest < BaseTestCase
  def setup
    @model = new_model
    @machine = StateMachines::Machine.new(@model, :use_transactions => true)
  end

  def test_should_rollback_transaction_if_false
    @machine.within_transaction(@model.new) do
      @model.create
      false
    end

    assert_equal 0, @model.count
  end

  def test_should_not_rollback_transaction_if_true
    @machine.within_transaction(@model.new) do
      @model.create
      true
    end

    assert_equal 1, @model.count
  end
end
