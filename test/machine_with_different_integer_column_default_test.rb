require_relative 'test_helper'
require 'stringio'

class MachineWithDifferentIntegerColumnDefaultTest < BaseTestCase
  def setup
    @original_stderr, $stderr = $stderr, StringIO.new

    @model = new_model do
      connection.add_column table_name, :status, :integer, :default => 0
    end
    @machine = StateMachines::Machine.new(@model, :status, :initial => :parked)
    @machine.state :parked, :value => 1
    @record = @model.new
  end

  def test_should_use_machine_default
    assert_equal 1, @record.status
  end

  def test_should_generate_a_warning
    assert_match(/Both Foo and its :status machine have defined a different default for "status". Use only one or the other for defining defaults to avoid unexpected behaviors\./, $stderr.string)
  end

  def teardown
    $stderr = @original_stderr
    super
  end
end

