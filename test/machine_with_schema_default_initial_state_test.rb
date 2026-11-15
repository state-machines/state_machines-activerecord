# frozen_string_literal: true

require_relative 'test_helper'
require 'stringio'

# A machine without an explicit +initial:+ picks its initial state from the
# attribute's schema default when that default names a defined state.
# See https://github.com/state-machines/state_machines-activerecord/issues/73
class MachineWithSchemaDefaultInitialStateTest < BaseTestCase
  def setup
    @original_stderr = $stderr
    $stderr = StringIO.new
  end

  def teardown
    $stderr = @original_stderr
    super
  end

  def test_should_use_string_column_default_as_initial_state
    model = model_with_column(:string, default: 'active', null: false)
    model.state_machine(:status) { state :active, :inactive }

    assert_equal 'active', model.new.status
  end

  def test_should_be_in_the_default_state
    model = model_with_column(:string, default: 'active', null: false)
    model.state_machine(:status) do
      state :active, :inactive
      event(:deactivate) { transition active: :inactive }
    end
    record = model.new

    assert record.status?(:active)
    assert_predicate record, :can_deactivate?
    assert record.deactivate
    assert_equal 'inactive', record.reload.status
  end

  def test_should_not_warn_about_conflicting_defaults
    model = model_with_column(:string, default: 'active', null: false)
    model.state_machine(:status) { state :active, :inactive }

    assert_no_match(/have defined a different default/, $stderr.string)
  end

  def test_should_prefer_explicit_initial_state
    model = model_with_column(:string, default: 'active', null: false)
    model.state_machine(:status, initial: :inactive) { state :active }

    assert_equal 'inactive', model.new.status
  end

  # Bug: a dynamic initial state only filled a blank attribute, and the column
  # default was already there, so the lambda was ignored. An explicit initial
  # state wins over the column default whether static or dynamic; the
  # conflicting-default warning still points out the two defaults.
  def test_should_apply_dynamic_initial_state_over_column_default
    model = model_with_column(:string, default: 'active', null: false)
    model.state_machine(:status, initial: ->(_record) { :inactive }) { state :active, :inactive }

    assert_equal 'inactive', model.new.status
    assert_match(/have defined a different default for "status"/, $stderr.string)
  end

  def test_should_evaluate_dynamic_initial_state_from_given_attributes
    model = model_with_column(:string, default: 'active', null: false)
    model.attribute :priority, :string
    model.state_machine(:status, initial: ->(record) { record.priority == 'high' ? :active : :inactive }) do
      state :active, :inactive
    end

    assert_equal 'active', model.new(priority: 'high').status
    assert_equal 'inactive', model.new(priority: 'low').status
  end

  def test_should_keep_given_state_over_dynamic_initial_state
    model = model_with_column(:string, default: 'active', null: false)
    model.state_machine(:status, initial: ->(_record) { :inactive }) { state :active, :inactive }

    assert_equal 'active', model.new(status: 'active').status
    assert_equal 'active', model.new { |record| record.status = 'active' }.status
  end

  def test_should_refuse_given_state_other_than_dynamic_initial_state_when_denied
    model = model_with_column(:string, default: 'active', null: false)
    model.state_machine(:status, initial: ->(_record) { :inactive }, direct_assignment: :deny) do
      state :active, :inactive
    end

    assert_equal 'inactive', model.new.status
    assert_raises(StateMachines::DirectStateAssignment) { model.new(status: 'active') }
  end

  def test_should_refuse_explicitly_assigned_non_initial_state
    model = model_with_column(:string, default: 'active', null: false)
    model.state_machine(:status, direct_assignment: :deny) { state :active, :inactive }

    assert_equal 'active', model.new(status: 'active').status
    assert_raises(StateMachines::DirectStateAssignment) { model.new(status: 'inactive') }
  end

  def test_should_ignore_default_that_is_not_a_defined_state
    model = model_with_column(:string, default: 'bogus')
    model.state_machine(:status) { state :active, :inactive }

    assert_nil model.new.status
  end

  def test_should_warn_when_default_is_not_a_defined_state
    model = model_with_column(:string, default: 'bogus')
    model.state_machine(:status) { state :active, :inactive }

    assert_match(/have defined a different default for "status"/, $stderr.string)
  end

  def test_should_keep_nil_initial_state_without_column_default
    model = model_with_column(:string)
    model.state_machine(:status) { state :active, :inactive }

    assert_nil model.new.status
  end

  def test_should_read_default_lazily_when_table_is_created_after_definition
    model = new_model(false)
    model.connection.drop_table(model.table_name) if model.table_exists?

    assert_nothing_raised do
      model.state_machine(:status) { state :active, :inactive }
    end

    model.connection.create_table(model.table_name) { |t| t.string :status, default: 'active', null: false }
    model.reset_column_information

    assert_equal 'active', model.new.status
  end

  def test_should_use_explicit_integer_value_column_default
    model = model_with_column(:integer, default: 1, null: false)
    model.state_machine(:status) do
      state :active, value: 1
      state :inactive, value: 2
    end
    record = model.new

    assert_equal 1, record.status
    assert record.status?(:active)
  end

  def test_should_use_auto_indexed_integer_column_default
    model = model_with_column(:integer, default: 1, null: false)
    model.state_machine(:status) { state :inactive, :active }
    record = model.new

    assert_equal 'active', record.status
    assert_no_match(/have defined a different default/, $stderr.string)
  end

  def test_should_use_aliased_column_default
    model = model_with_column(:string, default: 'active', null: false)
    model.alias_attribute :condition, :status
    model.state_machine(:status, attribute: :condition) { state :active, :inactive }

    assert_equal 'active', model.new.condition
    assert_no_match(/have defined a different default/, $stderr.string)
  end

  def test_should_use_attributes_api_default
    model = new_model do
      attribute :status, :string, default: 'active'
    end
    model.state_machine(:status) { state :active, :inactive }

    assert_equal 'active', model.new.status
  end

  private

  # Builds a model whose table has a +status+ column of the given type.
  #
  # @param type [Symbol] the column type
  # @param options [Hash] column options (+default:+, +null:+)
  # @return [Class] the model class
  def model_with_column(type, **)
    new_model do
      connection.add_column table_name, :status, type, **
    end
  end
end
