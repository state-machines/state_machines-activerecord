# frozen_string_literal: true

require_relative 'test_helper'

# Regression test: states with explicit integer values must work correctly.
# Without a fix, StateCollection#match returns nil because Machine#read returns
# the state name string ("parked") but state.value is an integer (1), so the
# value-based lookup never matches.
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

  def test_should_return_state_name_on_read
    assert_equal 'pending', @record.status
  end

  def test_status_name_returns_correct_symbol
    assert_equal :pending, @record.status_name
  end

  def test_should_accept_symbol_on_write
    @record.status = :declined
    assert_equal 'declined', @record.status
  end

  def test_should_persist_explicit_integer_on_save
    @record.status = :approved
    @record.save!
    raw = @model.connection.select_value("SELECT status FROM #{@model.quoted_table_name} WHERE id = #{@record.id}")
    assert_equal 1, raw.to_i
  end

  def test_should_reload_as_state_name
    @record.status = :declined
    @record.save!
    reloaded = @model.find(@record.id)
    assert_equal 'declined', reloaded.status
  end

  def test_transition_fires_correctly
    @record.approve!
    assert_equal 'approved', @record.status
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
end
