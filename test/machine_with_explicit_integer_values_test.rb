# frozen_string_literal: true

require_relative 'test_helper'

# Regression test for https://github.com/state-machines/state_machines-activerecord/issues/132
#
# Machines whose named states all declare explicit integer values
# (state :pending, value: 0) are defined for raw integer storage: reads return
# the integer, status_name returns the state name. The custom integer type
# must pass values through untouched for these machines instead of converting
# them to state name strings.
class MachineWithExplicitIntegerValuesTest < BaseTestCase
  def setup
    @model = new_model do
      connection.add_column table_name, :status, :integer, default: 0
    end

    @machine = StateMachines::Machine.new(@model, :status, initial: :pending) do
      state :pending,  value: 0
      state :approved, value: 1
      state :declined, value: 2

      event :approve do
        transition pending: :approved
      end

      event :decline do
        transition pending: :declined
      end
    end

    @record = @model.new
    @record.save!
  end

  def test_should_read_raw_integer_value
    assert_equal 0, @record.status
  end

  def test_status_name_returns_correct_symbol
    assert_equal :pending, @record.status_name
  end

  def test_should_accept_integer_on_write
    @record.status = 2

    assert_equal 2, @record.status
    assert_equal :declined, @record.status_name
  end

  def test_should_accept_numeric_string_on_write
    @record.status = '1'

    assert_equal 1, @record.status
    assert_equal :approved, @record.status_name
  end

  def test_should_persist_explicit_integer_on_save
    @record.approve!
    raw = @model.connection.select_value("SELECT status FROM #{@model.quoted_table_name} WHERE id = #{@record.id}")

    assert_equal 1, raw.to_i
  end

  def test_should_reload_as_raw_integer
    @record.decline!
    reloaded = @model.find(@record.id)

    assert_equal 2, reloaded.status
  end

  def test_transition_fires_correctly
    @record.approve!

    assert_equal 1, @record.status
  end

  def test_predicate_returns_correct_result
    assert @record.pending?
    refute @record.approved?
  end

  def test_scope_returns_correct_records
    approved = @model.new
    approved.save!
    approved.approve!

    assert_includes @model.with_status(:pending), @record
    assert_includes @model.with_status(:approved), approved
    refute_includes @model.with_status(:approved), @record
  end

  def test_scope_uses_raw_integer_relation_condition
    assert_equal({ 'status' => 1 }, @model.with_status(:approved).where_values_hash)
  end
end
