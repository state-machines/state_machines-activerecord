# frozen_string_literal: true

module StateMachines
  module Integrations
    module ActiveRecord
      # Administrative state changes outside the machine's events, mixed into
      # every model owning a state machine.
      module ForceState
        # Moves the record to +state+ without firing an event, then saves it.
        # No transition callbacks run, but validations and save callbacks do,
        # so auditing (e.g. paper_trail) records the change. Works whether or
        # not the machine denies direct assignment. Meant for data repair:
        # regular state changes go through events.
        #
        # @param state [Symbol, String, nil] the target state's name
        # @param machine [Symbol, String, nil] the machine's name; required
        #   when the model has several machines
        # @return [true]
        # @raise [ArgumentError] when +machine+ is missing or unknown
        # @raise [IndexError] when +state+ is not a state of the machine
        # @raise [StateMachines::PendingStateEvent] while an event attribute
        #   or a transition prepared by validation is queued
        # @raise [ActiveRecord::RecordInvalid] when the record is invalid
        def force_state!(state, machine: nil)
          target = ForceState.machine_for(self, machine)
          StateGuard.ensure_no_queued_work!(self, operation: 'force_state!')
          target.write(self, :state, target.states.fetch(state).value)
          save!
        end

        # @param record [ActiveRecord::Base] the record whose state is forced
        # @param name [Symbol, String, nil] the requested machine's name
        # @return [StateMachines::Machine] the machine to force
        # @raise [ArgumentError] when +name+ is missing or unknown
        def self.machine_for(record, name)
          machines = record.class.state_machines
          return machines.values.first if name.nil? && machines.size == 1

          key = name&.to_sym
          machines.fetch(key) do
            names = machines.keys.map(&:inspect).join(', ')
            raise ArgumentError, "#{record.class.name} has several state machines (#{names}); pass machine:" unless key

            raise ArgumentError, "#{record.class.name} has no state machine #{key.inspect}"
          end
        end
      end
    end
  end
end
