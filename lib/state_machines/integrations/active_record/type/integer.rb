# frozen_string_literal: true

module StateMachines
  module Type
    # Custom ActiveRecord attribute type for state machine attributes backed by
    # integer columns. Handles bidirectional conversion between state name strings
    # (used internally by the state machine) and integer values (stored in the DB).
    #
    # States without explicit integer values are mapped by their index position
    # in the states collection (0, 1, 2, …). States with an explicit integer
    # value (e.g. state :pending, value: 2) use that value directly.
    class Integer < ::ActiveRecord::Type::Value
      def initialize(states)
        @states = states
        super()
      end

      # integer from DB → state name string
      def deserialize(value)
        return nil if value.nil?
        int_val = value.to_i
        state = named_states.detect { |s| state_integer(s) == int_val }
        state ? state.name.to_s : value
      end

      # assignment (symbol / string / integer) → state name string (in-memory)
      def cast(value)
        return nil if value.nil?
        state = named_states.detect { |s| s.name.to_s == value.to_s }
        state ||= named_states.detect { |s| state_integer(s) == value.to_i } if value.respond_to?(:to_i)
        state ? state.name.to_s : value.to_s
      end

      # state name string → integer for DB write
      def serialize(value)
        return nil if value.nil?
        state = named_states.detect { |s| s.name.to_s == value.to_s }
        state ? state_integer(state) : value
      end

      def type
        :integer
      end

      private

      # All non-nil states in definition order — not memoized because states are
      # added to the collection after the type is instantiated.
      def named_states
        @states.reject { |s| s.name.nil? }
      end

      # Returns the integer to use for storage:
      # - explicit integer value if set (e.g. state :pending, value: 2)
      # - otherwise the index position among named states
      def state_integer(state)
        state.value.is_a?(::Integer) ? state.value : named_states.index(state)
      end
    end
  end
end
