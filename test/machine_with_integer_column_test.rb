# frozen_string_literal: true

require_relative 'test_helper'

class MachineWithIntegerColumnTest < BaseTestCase
  def setup
    @model = new_model do
      connection.add_column table_name, :status, :integer
    end

    @machine = StateMachines::Machine.new(@model, :status, initial: :pending)
    @machine.state :pending
    @machine.state :approved
    @machine.state :declined

    @machine.event :approve do
      transition pending: :approved
    end
    @machine.event :decline do
      transition pending: :declined
    end

    @record = @model.new
    @record.save!
  end

  def test_should_return_state_name_on_read
    assert_equal 'pending', @record.status
  end

  def test_should_accept_symbol_on_write
    @record.status = :declined
    assert_equal 'declined', @record.status
  end

  def test_should_accept_string_on_write
    @record.status = 'approved'
    assert_equal 'approved', @record.status
  end

  def test_should_persist_state_as_integer
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

  def test_status_name_returns_symbol
    assert_equal :pending, @record.status_name
  end

  def test_transition_fires_correctly
    @record.approve!
    assert_equal 'approved', @record.status
  end

  def test_scope_with_status_returns_correct_records
    approved = @model.new
    approved.save!
    approved.approve!

    assert_includes @model.with_status(:pending), @record
    refute_includes @model.with_status(:pending), approved
    assert_includes @model.with_status(:approved), approved
  end
end
