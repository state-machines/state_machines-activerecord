# frozen_string_literal: true

require_relative 'test_helper'

class MachineWithIntegerColumnTest < BaseTestCase
  def setup
    @model = new_model do
      connection.add_column table_name, :status, :integer
    end

    @machine = StateMachines::Machine.new(@model, :status, initial: :pending, direct_assignment: :deny)
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

  def test_should_accept_equivalent_symbol_on_write
    @record.status = :pending
    assert_equal 'pending', @record.status
    refute_predicate @record, :changed?
  end

  def test_should_accept_equivalent_string_and_integer_on_write
    @record.status = 'pending'
    @record.status = 0
    assert_equal 'pending', @record.status
    refute_predicate @record, :changed?
  end

  def test_should_refuse_other_state_on_write
    assert_raises(StateMachines::DirectStateAssignment) { @record.status = :declined }
    assert_raises(StateMachines::DirectStateAssignment) { @record.status = 2 }
    assert_equal 'pending', @record.status
  end

  def test_should_persist_state_as_integer
    @record.approve!
    raw = @model.connection.select_value("SELECT status FROM #{@model.quoted_table_name} WHERE id = #{@record.id}")
    assert_equal 1, raw.to_i
  end

  def test_should_reload_as_state_name
    @record.decline!
    reloaded = @model.find(@record.id)
    assert_equal 'declined', reloaded.status
  end

  def test_should_map_state_name_on_raw_repair
    @record.update_column(:status, :declined)
    raw = @model.connection.select_value("SELECT status FROM #{@model.quoted_table_name} WHERE id = #{@record.id}")
    assert_equal 2, raw.to_i
    assert_equal 'declined', @record.reload.status
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
