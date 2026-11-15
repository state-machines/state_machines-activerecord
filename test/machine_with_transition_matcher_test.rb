# frozen_string_literal: true

require_relative 'test_helper'

# Replays the checks of state_machines-rspec's +transition_from+ matcher
# against an ActiveRecord model:
#
#   it { is_expected.to transition_from :idle, to_state: :received, on_event: :receive }
#
# The matcher writes the from-state's value to the attribute, fires the event
# (+subject.receive+) and compares the attribute with the to-state's value.
# See https://github.com/state-machines/state_machines-activerecord/issues/64
class MachineWithTransitionMatcherTest < BaseTestCase
  def setup
    @model = new_model do
      connection.add_column table_name, :title, :string

      state_machine initial: :idle do
        event(:receive) { transition idle: :received }
      end
    end
  end

  def test_should_transition_from_idle_to_received
    record = @model.new

    assert transition_from?(record, :idle, to: :received, on: :receive)
  end

  def test_should_report_event_as_possible_from_idle
    record = @model.new
    enter_state(record, :idle)

    assert_predicate record, :can_receive?
    assert_equal :received, record.receive_transition.to_name
  end

  # The one behavioural difference from a plain Ruby class: the event runs the
  # machine's action, +save+. When the subject cannot be saved (e.g. a
  # required +belongs_to+, on by default since Rails 5) the event returns
  # false and the state is rolled back, so the matcher fails even though
  # +can_receive?+ is true.
  def test_should_fail_matcher_when_subject_cannot_be_saved
    @model.validates :title, presence: true
    record = @model.new

    assert_predicate record, :can_receive?
    refute transition_from?(record, :idle, to: :received, on: :receive)
    assert_equal 'idle', record.state
  end

  def test_should_transition_once_subject_is_valid
    @model.validates :title, presence: true
    record = @model.new(title: 'parcel')

    assert transition_from?(record, :idle, to: :received, on: :receive)
  end

  private

  # Mirrors StateMachinesIntrospector#valid_transition? after
  # HandleTransitionFromMatcher#enter_from_state.
  #
  # @return [Boolean] whether the matcher would pass
  def transition_from?(record, from, to:, on:)
    enter_state(record, from)
    record.public_send(on)
    record.state == @model.state_machine.states[to].value
  end

  # Mirrors HandleTransitionFromMatcher#enter_from_state.
  #
  # @return [void]
  def enter_state(record, name)
    machine = @model.state_machine
    record.public_send("#{machine.attribute}=", machine.states[name].value)
  end
end
