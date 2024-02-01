require_relative 'test_helper'

class MachineWithScopesTest < BaseTestCase
  def setup
    @model = new_model do
      connection.add_column table_name, :name, :string
    end
    @machine = StateMachines::Machine.new(@model)
    @machine.state :parked, :first_gear
    @machine.state :idling, :value => -> { 'idling' }
  end

  def test_should_allow_chaining_scopes_with_queries
    named = @model.create :state => 'parked', :name => 'a_name'
    @model.create :state => 'parked'

    assert_equal [named], @model.where(:name => 'a_name').with_state(:parked)
  end

  def test_should_create_singular_with_scope
    assert @model.respond_to?(:with_state)
  end

  def test_should_only_include_records_with_state_in_singular_with_scope
    parked = @model.create :state => 'parked'
    @model.create :state => 'idling'

    assert_equal [parked], @model.with_state(:parked).all
  end

  def test_should_allow_transparent_with_state_in_singular_with_scope
    @model.create :state => 'parked'
    @model.create :state => 'idling'

    assert_equal @model.all, @model.with_state(nil).all
  end

  def test_should_create_plural_with_scope
    assert @model.respond_to?(:with_states)
  end

  def test_should_only_include_records_with_states_in_plural_with_scope
    parked = @model.create :state => 'parked'
    idling = @model.create :state => 'idling'

    assert_equal [parked, idling], @model.with_states(:parked, :idling).all
  end

  def test_should_allow_transparent_with_states_in_plural_with_scope
    @model.create :state => 'parked'
    @model.create :state => 'idling'

    assert_equal @model.all, @model.with_states(nil).all
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
    @model.create :state => 'idling'

    assert_equal [parked], @model.without_state(:idling).all
  end

  def test_allow_transparent_without_state_in_singular_without_scope
    @model.create :state => 'parked'
    @model.create :state => 'idling'

    assert_equal @model.all, @model.without_state(nil).all
  end

  def test_should_create_plural_without_scope
    assert @model.respond_to?(:without_states)
  end

  def test_should_only_include_records_without_states_in_plural_without_scope
    parked = @model.create :state => 'parked'
    idling = @model.create :state => 'idling'
    @model.create :state => 'first_gear'

    assert_equal [parked, idling], @model.without_states(:first_gear).all
  end

  def test_allow_transparent_without_states_in_plural_without_scope
    @model.create :state => 'parked'
    @model.create :state => 'idling'
    @model.create :state => 'first_gear'

    assert_equal @model.all, @model.without_states(nil).all
  end

  def test_should_allow_chaining_scopes
    @model.create :state => 'parked'
    idling = @model.create :state => 'idling'

    assert_equal [idling], @model.without_state(:parked).with_state(:idling).all
  end

  def test_should_allow_chaining_transparent_scopes
    @model.create :state => 'parked'
    idling = @model.create :state => 'idling'

    assert_equal [idling], @model.with_state(nil).with_state(:idling).all
  end
end
