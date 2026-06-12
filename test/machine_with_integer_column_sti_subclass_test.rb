# frozen_string_literal: true

require_relative 'test_helper'

# Subclasses that extend an inherited machine get a cloned state collection,
# but they inherit the parent's custom integer attribute type, which references
# the parent machine's states. The integration must re-register the type on the
# subclass so subclass-added states serialize to their own integers instead of
# silently coercing to 0.
class MachineWithIntegerColumnStiSubclassTest < BaseTestCase
  def setup
    @base = new_model do
      connection.add_column table_name, :status, :integer, default: 0
    end

    @base_machine = StateMachines::Machine.new(@base, :status, initial: :pending) do
      state :pending
      state :shipped

      event :ship do
        transition pending: :shipped
      end
    end

    @subclass = Class.new(@base)
    @subclass_machine = @subclass.state_machine(:status) do
      state :returned

      event :return_order do
        transition shipped: :returned
      end
    end

    @record = @subclass.new
    @record.ship!
  end

  def test_subclass_machine_is_a_copy
    refute_same @base_machine, @subclass_machine
  end

  def test_subclass_added_state_persists_its_own_integer
    @record.return_order!
    raw = @subclass.connection.select_value("SELECT status FROM #{@subclass.quoted_table_name} WHERE id = #{@record.id}")

    assert_equal 2, raw.to_i
  end

  def test_subclass_added_state_reads_back
    @record.return_order!
    reloaded = @subclass.find(@record.id)

    assert_equal 'returned', reloaded.status
    assert_equal :returned, reloaded.status_name
  end

  def test_inherited_states_still_convert_on_subclass
    assert_equal 'shipped', @record.status
    assert @record.shipped?
  end

  def test_base_class_type_unaffected
    base_record = @base.new
    base_record.ship!
    raw = @base.connection.select_value("SELECT status FROM #{@base.quoted_table_name} WHERE id = #{base_record.id}")

    assert_equal 1, raw.to_i
    assert_equal 'shipped', @base.find(base_record.id).status
  end
end
