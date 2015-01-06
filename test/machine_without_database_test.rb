require_relative 'test_helper'

class MachineWithoutDatabaseTest < BaseTestCase
  def setup
    @model = new_model(false) do
      # Simulate the database not being available entirely
      def self.connection
        raise ActiveRecord::ConnectionNotEstablished
      end

      def self.connected?
        false
      end
    end
  end

  def test_should_allow_machine_creation
    assert_nothing_raised { StateMachines::Machine.new(@model) }
  end
end
