require_relative 'test_helper'

class IntegrationTest < BaseTestCase
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
    assert_equal({action: :save, use_transactions: true}, StateMachines::Integrations::ActiveRecord.defaults)
  end

  def test_should_have_a_locale_path
    assert_not_nil StateMachines::Integrations::ActiveRecord.locale_path
  end
end
