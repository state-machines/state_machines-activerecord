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
    #
    # When *every* named state has an explicit integer value, the column already
    # stores the canonical state values and no name<->integer conversion is
    # needed. In that case the type delegates to the column's original integer
    # type, preserving the classic raw-integer behavior
    # (e.g. record.status # => 1, record.status_name # => :approved).
    class Integer < ::ActiveRecord::Type::Value
      # @param states [StateMachines::StateCollection] live collection of the
      #   machine's states; held by reference because states are defined after
      #   the type is registered
      # @param raw_type [ActiveModel::Type::Value, nil] the column's original
      #   attribute type, used verbatim in passthrough mode so adapter-specific
      #   integer behavior (limits, range checks) is preserved
      def initialize(states, raw_type: nil)
        @states = states
        @raw_type = raw_type || ::ActiveModel::Type::Integer.new
        super()
      end

      # Converts an integer from the database to a state name string.
      #
      # @param value [Integer, String, nil] raw database value
      # @return [String, Integer, nil] state name, or the original type's value
      #   in passthrough mode, or the raw value when no state matches
      def deserialize(value)
        states = named_states
        return @raw_type.deserialize(value) if passthrough?(states)
        return nil if value.nil?

        int_val = value.to_i
        state = states.detect { |s| state_integer(s, states) == int_val }
        state ? state.name.to_s : value
      end

      # Converts an assigned value (symbol, string, or integer) to the in-memory
      # state name string.
      #
      # @param value [Symbol, String, Integer, nil] assigned value
      # @return [String, Integer, nil] state name, or the original type's cast
      #   in passthrough mode
      def cast(value)
        states = named_states
        return @raw_type.cast(value) if passthrough?(states)
        return nil if value.nil?

        state = states.detect { |s| s.name.to_s == value.to_s }
        state ||= states.detect { |s| state_integer(s, states) == value.to_i } if value.respond_to?(:to_i)
        state ? state.name.to_s : value.to_s
      end

      # Converts a state name string to its integer for the database write.
      #
      # @param value [String, Symbol, Integer, nil] in-memory value
      # @return [Integer, nil] integer to store
      def serialize(value)
        states = named_states
        return @raw_type.serialize(value) if passthrough?(states)
        return nil if value.nil?

        state = states.detect { |s| s.name.to_s == value.to_s }
        state ? state_integer(state, states) : value
      end

      # @return [Symbol] the ActiveModel type identifier
      def type
        :integer
      end

      private

      # All non-nil states in definition order, not memoized because states are
      # added to the collection after the type is instantiated.
      #
      # @return [Array<StateMachines::State>]
      def named_states
        @states.reject { |s| s.name.nil? }
      end

      # Whether the machine was defined for raw integer storage, in which case
      # conversion would change documented behavior. True when every named state
      # declares an explicit integer value. Evaluated lazily on every call
      # because states (and their values) are defined after the type is
      # registered. Uses value(false) so dynamic (Proc) state values are never
      # evaluated for this metadata decision.
      #
      # @param states [Array<StateMachines::State>] pre-computed named states
      # @return [Boolean]
      def passthrough?(states)
        states.any? && states.all? { |s| s.value(false).is_a?(::Integer) }
      end

      # The integer to use for storage: the explicit state value if set
      # (e.g. state :pending, value: 2), otherwise the index position among
      # named states.
      #
      # @param state [StateMachines::State]
      # @param states [Array<StateMachines::State>] pre-computed named states
      # @return [Integer]
      def state_integer(state, states)
        value = state.value(false)
        value.is_a?(::Integer) ? value : states.index(state)
      end
    end
  end
end
