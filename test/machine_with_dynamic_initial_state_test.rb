require_relative 'test_helper'

class MachineWithDynamicInitialStateTest < BaseTestCase
  def setup
    @model = new_model do
      attr_accessor :value
    end
    @machine = StateMachines::Machine.new(@model, :initial => lambda { |object| :parked })
    @machine.state :parked
  end

  def test_should_set_initial_state_on_created_object
    record = @model.new
    assert_equal 'parked', record.state
  end

  def test_should_still_set_attributes
    record = @model.new(:value => 1)
    assert_equal 1, record.value
  end

  def test_should_still_allow_initialize_blocks
    block_args = nil
    record = @model.new do |*args|
      block_args = args
    end

    assert_equal [record], block_args
  end

  def test_should_set_attributes_prior_to_initialize_block
    state = nil
    @model.new do |record|
      state = record.state
    end

    assert_equal 'parked', state
  end

  def test_should_set_attributes_prior_to_after_initialize_hook
    state = nil
    @model.after_initialize do |record|
      state = record.state
    end
    @model.new
    assert_equal 'parked', state
  end

  def test_should_set_initial_state_after_setting_attributes
    @model.class_eval do
      attr_accessor :state_during_setter

      remove_method :value=
      define_method(:value=) do |value|
        self.state_during_setter = state || 'nil'
      end
    end

    record = @model.new(:value => 1)
    assert_equal 'nil', record.state_during_setter
  end

  def test_should_not_set_initial_state_after_already_initialized
    record = @model.new(:value => 1)
    assert_equal 'parked', record.state

    record.state = 'idling'
    record.attributes = {}
    assert_equal 'idling', record.state
  end

  def test_should_persist_initial_state
    record = @model.new
    record.save
    record.reload
    assert_equal 'parked', record.state
  end

  def test_should_persist_initial_state_on_dup
    record = @model.create.dup
    record.save
    record.reload
    assert_equal 'parked', record.state
  end

  def test_should_use_stored_values_when_loading_from_database
    @machine.state :idling

    record = @model.find(@model.create(:state => 'idling').id)
    assert_equal 'idling', record.state
  end

  def test_should_use_stored_values_when_loading_from_database_with_nil_state
    @machine.state nil

    record = @model.find(@model.create(:state => nil).id)
    assert_nil record.state
  end
end
