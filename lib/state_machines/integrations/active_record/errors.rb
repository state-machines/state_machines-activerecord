# frozen_string_literal: true

module StateMachines
  # Raised when a state machine attribute of an ActiveRecord model is written
  # directly with a different state: through its setter, mass assignment,
  # an attribute alias, +record[:state] =+ or +write_attribute+, while
  # building a record with a state other than its initial state, or when
  # saving a state that was changed without going through the setter.
  #
  # State changes go through events. Raw persistence (+update_column+,
  # +update_columns+, +update_all+, +insert_all+, SQL) stays outside the
  # machine for data repair.
  #
  # A refused assignment is not an event refusal: no refusal reason is
  # recorded for it.
  #
  # @example
  #   vehicle.state = 'idling'
  #   # => StateMachines::DirectStateAssignment: Cannot assign Vehicle#state
  #   #    directly from "parked" to "idling" (state machine :state). ...
  class DirectStateAssignment < Error
    # @return [StateMachines::Machine] the machine owning the attribute
    attr_reader :machine

    # @return [Symbol] the machine's attribute
    attr_reader :attribute

    # @return [Object] the state value the record holds legitimately
    attr_reader :from

    # @return [Object] the requested (or bypassed) state value
    attr_reader :to

    # @param object [ActiveRecord::Base] the record being written
    # @param machine [StateMachines::Machine] the machine owning the attribute
    # @param from [Object] the state value the record holds legitimately
    # @param to [Object] the requested (or bypassed) state value
    def initialize(object, machine:, from:, to:)
      @machine = machine
      @attribute = machine.attribute
      @from = from
      @to = to

      super(object, build_message(object))
    end

    private

    # @param object [ActiveRecord::Base] the record being written
    # @return [String] the error message
    def build_message(object)
      "Cannot assign #{object.class.name}##{attribute} directly from #{from.inspect} to #{to.inspect} " \
        "(state machine #{machine.name.inspect}). State changes go through events: fire one " \
        "(record.<event> / record.<event>!) or set #{machine.attribute(:event)} and save; in forms, " \
        "permit #{machine.attribute(:event)}, not #{attribute}. For data repair outside the state " \
        'machine use update_column, update_columns, update_all or SQL (no callbacks run), ' \
        'then reload live instances.'
    end
  end

  # Raised by +becomes+ or +force_state!+ while a record still has queued
  # state machine work (a pending event attribute or a transition prepared by
  # validation): +becomes+ would silently drop it, +force_state!+ would race
  # it.
  class PendingStateEvent < Error
    # @return [StateMachines::Machine] the machine with queued work
    attr_reader :machine

    # @return [Symbol, String] the queued event
    attr_reader :event

    # @param object [ActiveRecord::Base] the record being converted
    # @param machine [StateMachines::Machine] the machine with queued work
    # @param event [Symbol, String] the queued event
    # @param operation [String] the refused method
    def initialize(object, machine, event, operation: 'becomes')
      @machine = machine
      @event = event

      super(object, "Cannot call #{operation} on #{object.class.name} while state machine #{machine.name.inspect} " \
                    "has queued work (#{machine.attribute(:event)} = #{event.inspect}); " \
                    'save the record or clear the event first.')
    end
  end
end
