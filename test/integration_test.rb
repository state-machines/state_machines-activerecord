# frozen_string_literal: true

require_relative 'test_helper'

class IntegrationTest < BaseTestCase
  def teardown
    StateMachines::Integrations::ActiveRecord.auto_convert_integer_state_attributes = true
    super
  end

  def test_should_have_an_integration_name
    assert_equal :active_record, StateMachines::Integrations::ActiveRecord.integration_name
  end

  def test_should_be_before_activemodel
    integrations = StateMachines::Integrations.list.to_a
    assert StateMachines::Integrations::ActiveRecord, integrations.first
    assert StateMachines::Integrations::ActiveModel, integrations.last
  end

  def test_should_match_if_class_inherits_from_active_record
    assert StateMachines::Integrations::ActiveRecord.matches?(new_model)
  end

  def test_should_not_match_if_class_does_not_inherit_from_active_record
    refute StateMachines::Integrations::ActiveRecord.matches?(Class.new)
  end

  def test_should_have_defaults
    assert_equal({ action: :save, use_transactions: true }, StateMachines::Integrations::ActiveRecord.defaults)
  end

  def test_should_auto_convert_integer_state_attributes_by_default
    assert_equal true, StateMachines::Integrations::ActiveRecord.auto_convert_integer_state_attributes
  end

  def test_should_allow_integer_state_attribute_conversion_to_be_disabled
    StateMachines::Integrations::ActiveRecord.auto_convert_integer_state_attributes = false

    assert_equal false, StateMachines::Integrations::ActiveRecord.auto_convert_integer_state_attributes
  end
end
