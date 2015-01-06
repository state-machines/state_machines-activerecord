require_relative 'test_helper'
require 'stringio'

class MachineWithCustomAttributeTest < BaseTestCase
  def setup
    @original_stderr, $stderr = $stderr, StringIO.new

    @model = new_model
    @machine = StateMachines::Machine.new(@model, :public_state, :attribute => :state)
    @record = @model.new
  end

  def test_should_not_delegate_attribute_predicate_with_different_attribute
    assert_raise(ArgumentError) { @record.public_state? }
  end

  def teardown
    $stderr = @original_stderr
    super
  end
end
