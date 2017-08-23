require_relative 'test_helper'
require 'stringio'

class MachineWithSameIntegerColumnDefaultTest < BaseTestCase
  def setup
    @original_stderr, $stderr = $stderr, StringIO.new

    @model = new_model do
      connection.add_column table_name, :status, :integer, :default => 1
    end
    @machine = StateMachines::Machine.new(@model, :status, :initial => :parked) do
      state :parked, :value => 1
    end
    @record = @model.new
  end

  def test_should_use_machine_default
    assert_equal 1, @record.status
  end

  def test_should_not_generate_a_warning
    assert_no_match(/have defined a different default/, $stderr.string)
  end

  def teardown
    $stderr = @original_stderr
    super
  end
end

