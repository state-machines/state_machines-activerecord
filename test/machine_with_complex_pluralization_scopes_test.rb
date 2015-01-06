require_relative 'test_helper'

class MachineWithComplexPluralizationScopesTest < BaseTestCase
  def setup
    @model = new_model
    @machine = StateMachines::Machine.new(@model, :status)
  end

  def test_should_create_singular_with_scope
    assert @model.respond_to?(:with_status)
  end

  def test_should_create_plural_with_scope
    assert @model.respond_to?(:with_statuses)
  end
end
