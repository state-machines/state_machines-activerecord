# frozen_string_literal: true

require_relative 'test_helper'

class MachineWithIntegerColumnConversionDisabledTest < BaseTestCase
  def setup
    StateMachines::Integrations::ActiveRecord.auto_convert_integer_state_attributes = false

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

  def teardown
    StateMachines::Integrations::ActiveRecord.auto_convert_integer_state_attributes = true
    super
  end

  def test_should_not_register_custom_integer_type
    refute @machine.integer_type_registered?
    assert_equal :integer, @model.type_for_attribute('status').type
  end

  def test_should_read_raw_integer_value
    assert_equal 0, @record.status
  end

  def test_status_name_returns_symbol
    assert_equal :pending, @record.status_name
  end

  def test_transition_fires_correctly_with_raw_integer_values
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

  def test_should_persist_raw_integer_on_save
    @record.approve!
    @record.save!
    raw = @model.connection.select_value("SELECT status FROM #{@model.quoted_table_name} WHERE id = #{@record.id}")

    assert_equal 1, raw.to_i
  end
end
