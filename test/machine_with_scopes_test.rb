require_relative 'test_helper'

class MachineWithScopesTest < BaseTestCase
  def setup
    @model = new_model
    @machine = StateMachines::Machine.new(@model)
    @machine.state :parked, :first_gear
    @machine.state :idling, :value => -> { 'idling' }
  end

  def test_should_create_singular_with_scope
    assert @model.respond_to?(:with_state)
  end

  def test_should_only_include_records_with_state_in_singular_with_scope
    parked = @model.create :state => 'parked'
    @model.create :state => 'idling'

    assert_equal [parked], @model.with_state(:parked).all
  end

  def test_should_create_plural_with_scope
    assert @model.respond_to?(:with_states)
  end

  def test_should_only_include_records_with_states_in_plural_with_scope
    parked = @model.create :state => 'parked'
    idling = @model.create :state => 'idling'

    assert_equal [parked, idling], @model.with_states(:parked, :idling).all
  end

  def test_should_allow_lookup_by_string_name
    parked = @model.create :state => 'parked'
    idling = @model.create :state => 'idling'

    assert_equal [parked, idling], @model.with_states('parked', 'idling').all
  end

  def test_should_create_singular_without_scope
    assert @model.respond_to?(:without_state)
  end

  def test_should_only_include_records_without_state_in_singular_without_scope
    parked = @model.create :state => 'parked'
    idling = @model.create :state => 'idling'

    assert_equal [parked], @model.without_state(:idling).all
  end

  def test_should_create_plural_without_scope
    assert @model.respond_to?(:without_states)
  end

  def test_should_only_include_records_without_states_in_plural_without_scope
    parked = @model.create :state => 'parked'
    idling = @model.create :state => 'idling'
    first_gear = @model.create :state => 'first_gear'

    assert_equal [parked, idling], @model.without_states(:first_gear).all
  end

  def test_should_allow_chaining_scopes
    parked = @model.create :state => 'parked'
    idling = @model.create :state => 'idling'

    assert_equal [idling], @model.without_state(:parked).with_state(:idling).all
  end
end

