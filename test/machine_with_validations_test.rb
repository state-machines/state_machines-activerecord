require_relative 'test_helper'

class MachineWithValidationsTest < BaseTestCase
  def setup
    @model = new_model
    @machine = StateMachines::Machine.new(@model)
    @machine.state :parked

    @record = @model.new
  end

  def test_should_invalidate_using_errors
    I18n.backend = I18n::Backend::Simple.new
    @record.state = 'parked'

    @machine.invalidate(@record, :state, :invalid_transition, [[:event, 'park']])
    assert_equal ['State cannot transition via "park"'], @record.errors.full_messages
  end

  def test_should_auto_prefix_custom_attributes_on_invalidation
    @machine.invalidate(@record, :event, :invalid)

    assert_equal ['State event is invalid'], @record.errors.full_messages
  end

  def test_should_clear_errors_on_reset
    @record.state = 'parked'
    @record.errors.add(:state, 'is invalid')

    @machine.reset(@record)
    assert_equal [], @record.errors.full_messages
  end

  def test_should_be_valid_if_state_is_known
    @record.state = 'parked'

    assert @record.valid?
  end

  def test_should_not_be_valid_if_state_is_unknown
    @record.state = 'invalid'

    refute @record.valid?
    assert_equal ['State is invalid'], @record.errors.full_messages
  end
end

