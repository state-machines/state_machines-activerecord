# frozen_string_literal: true

# Use lazy evaluation to avoid circular dependencies with frozen default_messages
# This ensures messages can be updated after gem loading while maintaining thread safety
{ en: {
  activerecord: {
    errors: {
      messages: {
        invalid: ->(*) { StateMachines::Machine.default_messages[:invalid] },
        invalid_event: ->(*) { format(StateMachines::Machine.default_messages[:invalid_event], '%<state>s') },
        invalid_transition: ->(*) { format(StateMachines::Machine.default_messages[:invalid_transition], '%<event>s') }
      }
    }
  }
} }
