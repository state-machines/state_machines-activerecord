# frozen_string_literal: true

require_relative 'test_helper'

# Machines on attributes that are not database columns: a plain
# +attr_accessor+ or an Attributes API +attribute+ without a column.
# See https://github.com/state-machines/state_machines-activerecord/issues/93
module TransientStateAttributeTests
  def setup
    @model = build_model(initial: :one)
  end

  # Builds a model with a transient +status+ machine.
  #
  # @param initial [Symbol, Proc] the machine's initial state
  # @param direct_assignment [Symbol] the machine's direct_assignment mode
  # @return [Class] the model class
  def build_model(initial:, direct_assignment: :allow)
    kind = transient_kind
    new_model do
      kind == :accessor ? attr_accessor(:status) : attribute(:status, :string)
      attr_accessor :gubbins, :validated

      state_machine :status, initial: initial, direct_assignment: direct_assignment do
        event(:one_to_two) { transition one: :two }
        event(:two_to_three) { transition two: :three }

        state :one, :two do
          validate do |record|
            record.validated = true
            record.errors.add(:gubbins, 'missing') if record.gubbins.nil?
          end
        end
        state :three
      end
    end
  end

  def test_should_initialize_state_on_new_record
    assert_equal 'one', @model.new.status
  end

  def test_should_initialize_state_on_loaded_record
    id = @model.create!(gubbins: 1).id

    assert_equal 'one', @model.find(id).status
  end

  def test_should_be_able_to_fire_events_on_loaded_record
    id = @model.create!(gubbins: 1).id
    record = @model.find(id)
    record.gubbins = 1

    assert_predicate record, :can_one_to_two?
    assert record.one_to_two
    assert_equal 'two', record.status
  end

  def test_should_run_state_validations_on_new_record
    record = @model.new

    refute_predicate record, :valid?
    assert record.validated
    assert_includes record.errors[:gubbins], 'missing'
  end

  def test_should_run_state_validations_when_transitioning
    id = @model.create!(gubbins: 1).id
    record = @model.find(id)

    refute record.one_to_two
    assert record.validated
    assert_includes record.errors[:gubbins], 'missing'
    assert_equal 'one', record.status
  end

  def test_should_not_run_state_validations_outside_scoped_states
    record = @model.new(gubbins: 1)
    record.one_to_two(false)
    record.two_to_three(false)
    record.gubbins = nil

    assert_predicate record, :valid?
    refute record.validated
  end

  def test_should_initialize_state_before_after_initialize
    @model.after_initialize { one_to_two(false) if persisted? }
    id = @model.create!(gubbins: 1).id

    assert_equal 'two', @model.find(id).status
  end

  def test_should_refuse_direct_state_write_in_after_initialize
    model = build_model(initial: :one, direct_assignment: :deny)
    model.after_initialize { self.status = 'three' if persisted? }
    id = model.create!(gubbins: 1).id

    assert_raises(StateMachines::DirectStateAssignment) { model.find(id) }
  end

  def test_should_evaluate_dynamic_initial_state_against_loaded_record
    model = build_model(initial: ->(record) { record.persisted? ? :two : :one })
    id = model.create!(gubbins: 1).id

    assert_equal 'one', model.new.status
    assert_equal 'two', model.find(id).status
  end
end

class MachineWithAttrAccessorStateAttributeTest < BaseTestCase
  include TransientStateAttributeTests

  private

  def transient_kind = :accessor
end

class MachineWithAttributesApiStateAttributeTest < BaseTestCase
  include TransientStateAttributeTests

  private

  def transient_kind = :attribute
end

# Loading a record must not re-initialize a column-backed state: a NULL in the
# database is the record's state, not a blank to fill.
class MachineWithColumnStateAttributeLoadTest < BaseTestCase
  def test_should_not_initialize_state_of_loaded_record
    model = new_model do
      state_machine initial: :parked
    end
    id = model.create!.id
    model.where(id: id).update_all(state: nil)

    assert_nil model.find(id).state
  end
end
