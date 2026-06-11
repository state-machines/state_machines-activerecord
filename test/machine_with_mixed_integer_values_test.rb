# frozen_string_literal: true

require_relative 'test_helper'

# Machines mixing explicit integer values with auto-indexed states keep the
# transparent name conversion, while machine internals match each state on its
# canonical state.value (integer for explicit states, name string for
# auto-indexed ones).
class MachineWithMixedIntegerValuesTest < BaseTestCase
  def setup
    @model = new_model do
      connection.add_column table_name, :status, :integer, default: 0
    end

    @machine = StateMachines::Machine.new(@model, :status, initial: :pending) do
      state :pending            # auto-indexed => 0
      state :approved, value: 5 # explicit

      event :approve do
        transition pending: :approved
      end
    end

    @record = @model.new
    @record.save!
  end

  def test_should_read_state_name
    assert_equal 'pending', @record.status
  end

  def test_status_name_returns_correct_symbol
    assert_equal :pending, @record.status_name
  end

  def test_predicate_returns_correct_result
    assert @record.pending?
    refute @record.approved?
  end

  def test_transition_fires_correctly
    @record.approve!

    assert_equal 'approved', @record.status
    assert @record.approved?
  end

  def test_should_persist_explicit_integer_on_save
    @record.approve!
    raw = @model.connection.select_value("SELECT status FROM #{@model.quoted_table_name} WHERE id = #{@record.id}")

    assert_equal 5, raw.to_i
  end

  def test_should_reload_as_state_name
    @record.approve!
    reloaded = @model.find(@record.id)

    assert_equal 'approved', reloaded.status
    assert_equal :approved, reloaded.status_name
  end
end
