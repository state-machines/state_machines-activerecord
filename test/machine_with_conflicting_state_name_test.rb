require_relative 'test_helper'
require 'stringio'

class MachineWithConflictingStateNameTest < BaseTestCase
  def setup
    @original_stderr, $stderr = $stderr, StringIO.new

    @model = new_model
  end

  def test_should_output_warning_with_same_machine_name
    @machine = StateMachines::Machine.new(@model)
    @machine.state :state

    assert_match(/^Instance method "state\?" is already defined in Foo, use generic helper instead.*\n$/, $stderr.string)
  end

  def test_should_output_warning_with_same_machine_attribute
    @machine = StateMachines::Machine.new(@model, :public_state, :attribute => :state)
    @machine.state :state

    assert_match(/^Instance method "state\?" is already defined in Foo, use generic helper instead.*\n$/, $stderr.string)
  end

  def teardown
    $stderr = @original_stderr
    super
  end
end
