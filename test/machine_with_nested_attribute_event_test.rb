# frozen_string_literal: true

require_relative 'test_helper'

# Regression test for issue #91: when a before_transition callback on one
# machine sets another machine's *_event attribute, the nested transition's
# after_transition callbacks must run within the same save (with the same
# transition object) instead of being skipped and replayed with stale data
# on the next save.
class MachineWithNestedAttributeEventTest < BaseTestCase
  def setup
    @model = new_model(:vehicle) do
      connection.add_column table_name, :location_state, :string
    end

    events = @events = []

    @model.state_machine initial: :parked do
      state :parked, :driving

      event(:start) { transition any => :driving }
      event(:park)  { transition any => :parked }

      before_transition any => :parked do |vehicle, transition|
        events << [:before_state, transition]
        vehicle.location_state_event = 'garage'
      end

      after_transition any => any do |_vehicle, transition|
        events << [:after_state, transition]
      end
    end

    @model.state_machine :location_state, initial: :garaged do
      state :garaged, :outside

      event(:garage) { transition any => :garaged }
      event(:drive)  { transition any => :outside }

      before_transition any => any do |_vehicle, transition|
        events << [:before_location, transition]
      end

      after_transition any => any do |_vehicle, transition|
        events << [:after_location, transition]
      end
    end

    @record = @model.create!
    @record.drive!
    @record.start!
    @events.clear
  end

  def test_should_run_nested_after_transition_within_same_save
    @record.park!

    assert_equal %i[before_state before_location after_state after_location], @events.map(&:first)
  end

  def test_should_pass_same_transition_object_to_nested_before_and_after
    @record.park!

    before_location = @events.detect { |name, _| name == :before_location }
    after_location = @events.detect { |name, _| name == :after_location }

    assert_same before_location[1], after_location[1]
    assert_equal :outside, after_location[1].from_name
    assert_equal :garaged, after_location[1].to_name
  end

  def test_should_not_replay_stale_transition_on_subsequent_save
    @record.park!
    @events.clear
    @record.park!

    assert_equal %i[before_state before_location after_state after_location], @events.map(&:first)

    location_transitions = @events.select { |name, _| name.to_s.end_with?('location') }.map(&:last)

    location_transitions.each do |transition|
      assert_equal :garaged, transition.from_name
      assert_equal :garaged, transition.to_name
    end
  end

  def test_should_persist_both_states
    @record.park!
    @record.reload

    assert_equal 'parked', @record.state
    assert_equal 'garaged', @record.location_state
  end

  def test_should_clear_stored_transition_references_after_save
    @record.park!

    assert_nil @record.send(:location_state_event_transition)
    assert_nil @record.instance_variable_get(:@_state_machine_event_transitions)
  end
end
