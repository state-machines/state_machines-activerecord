# frozen_string_literal: true

require_relative 'test_helper'

# A machine declared on an abstract class is inherited by its concrete
# subclasses with the abstract class as its owner. The abstract class has no
# table, so the machine must read the schema from the record's own class when
# loading records of a subclass.
class MachineWithAbstractOwnerClassTest < BaseTestCase
  def setup
    table_name = "abstract_owners_#{SecureRandom.hex(6)}"
    ActiveRecord::Base.connection.create_table(table_name, force: true) { |t| t.string(:state) }

    @abstract = Class.new(ActiveRecord::Base) do
      self.abstract_class = true

      def self.name
        'AbstractOwner'
      end

      state_machine initial: :parked do
        event(:ignite) { transition parked: :idling }
      end
    end

    @model = Class.new(@abstract) do
      self.table_name = table_name

      def self.name
        'AbstractOwnerSubclass'
      end
    end
  end

  def test_should_keep_the_abstract_class_as_the_machine_owner
    assert_same @abstract, @model.state_machine.owner_class
  end

  def test_should_load_a_record_of_a_concrete_subclass
    id = @model.create!.id

    assert_equal 'parked', @model.find(id).state
  end

  def test_should_fire_events_on_a_loaded_record
    record = @model.find(@model.create!.id)

    assert record.ignite
    assert_equal 'idling', @model.find(record.id).state
  end
end
