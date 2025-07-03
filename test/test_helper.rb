# frozen_string_literal: true

require 'debug' if RUBY_ENGINE == 'ruby'
require 'minitest/reporters'
Minitest::Reporters.use!(Minitest::Reporters::SpecReporter.new)

# Ensure our local lib directory is loaded first
$LOAD_PATH.unshift File.expand_path('../lib', __dir__)

require 'state_machines-activerecord'
require 'state_machines/test_helper'
require 'minitest/autorun'
require 'securerandom'

# Establish database connection
ActiveRecord::Base.establish_connection('adapter' => 'sqlite3', 'database' => ':memory:')
ActiveRecord::Base.logger = Logger.new("#{File.dirname(__FILE__)}/../log/active_record.log")
ActiveSupport.test_order = :random

class BaseTestCase < ActiveSupport::TestCase
  include StateMachines::TestHelper
  protected

  # Creates a new ActiveRecord model (and the associated table)
  def new_model(create_table = :foo, &)
    name = create_table || :foo
    table_name = "#{name}_#{SecureRandom.hex(6)}"

    model = Class.new(ActiveRecord::Base) do
      self.table_name = table_name.to_s
      connection.create_table(table_name, force: true) { |t| t.string(:state) } if create_table

      define_method(:abort_from_callback) do
        throw :abort
      end

      (
      class << self
        self
      end).class_eval do
        define_method(:name) { name.to_s.capitalize }
      end
    end
    model.class_eval(&) if block_given?
    model.reset_column_information if create_table
    model
  end

  def clear_active_support_dependencies
    return unless defined?(ActiveSupport::Dependencies)

    if ActiveSupport::Dependencies.respond_to?(:autoloader=)
      ActiveSupport::Dependencies.autoloader ||= stubbed_autoloader
    end

    ActiveSupport::Dependencies.clear
  end

  def stubbed_autoloader
    Object.new.tap do |obj|
      obj.define_singleton_method(:reload) {}
    end
  end
end
