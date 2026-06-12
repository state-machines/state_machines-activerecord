# frozen_string_literal: true

require_relative 'test_helper'
require 'stringio'

# Auto-indexed integer machines store the first state as 0, so a column
# default of 0 matches the initial state and must not trigger the
# conflicting-default warning. A genuinely different default still warns.
class MachineWithSameAutoIndexedIntegerColumnDefaultTest < BaseTestCase
  def setup
    @original_stderr = $stderr
    $stderr = StringIO.new

    @model = new_model do
      connection.add_column table_name, :status, :integer, default: 0
    end
    @machine = StateMachines::Machine.new(@model, :status, initial: :open) do
      state :open
      state :closed
    end
    @record = @model.new
  end

  def teardown
    $stderr = @original_stderr
    super
  end

  def test_should_use_machine_default
    assert_equal 'open', @record.status
  end

  def test_should_not_generate_a_warning
    assert_no_match(/have defined a different default/, $stderr.string)
  end
end

class MachineWithDifferentAutoIndexedIntegerColumnDefaultTest < BaseTestCase
  def setup
    @original_stderr = $stderr
    $stderr = StringIO.new

    @model = new_model do
      connection.add_column table_name, :status, :integer, default: 1
    end
    @machine = StateMachines::Machine.new(@model, :status, initial: :open) do
      state :open
      state :closed
    end
    @record = @model.new
  end

  def teardown
    $stderr = @original_stderr
    super
  end

  def test_should_generate_a_warning
    assert_match(/have defined a different default/, $stderr.string)
  end
end
