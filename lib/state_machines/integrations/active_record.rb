# frozen_string_literal: true

require 'state_machines-activemodel'
require 'active_record'
require 'state_machines/integrations/active_record/version'

module StateMachines
  module Integrations # :nodoc:
    # Adds support for integrating state machines with ActiveRecord models.
    #
    # == Examples
    #
    # Below is an example of a simple state machine defined within an
    # ActiveRecord model:
    #
    #   class Vehicle < ApplicationRecord
    #     state_machine :initial => :parked do
    #       event :ignite do
    #         transition :parked => :idling
    #       end
    #     end
    #   end
    #
    # The examples in the sections below will use the above class as a
    # reference.
    #
    # == Actions
    #
    # By default, the action that will be invoked when a state is transitioned
    # is the +save+ action.  This will cause the record to save the changes
    # made to the state machine's attribute.  *Note* that if any other changes
    # were made to the record prior to transition, then those changes will
    # be saved as well.
    #
    # For example,
    #
    #   vehicle = Vehicle.create          # => #<Vehicle id: 1, name: nil, state: "parked">
    #   vehicle.name = 'Ford Explorer'
    #   vehicle.ignite                    # => true
    #   vehicle.reload                    # => #<Vehicle id: 1, name: "Ford Explorer", state: "idling">
    #
    # *Note* that if you want a transition to update additional attributes of the record,
    # either the changes need to be made in a +before_transition+ callback or you need
    # to save the record manually.
    #
    # == Events
    #
    # As described in StateMachines::InstanceMethods#state_machine, event
    # attributes are created for every machine that allow transitions to be
    # performed automatically when the object's action (in this case, :save)
    # is called.
    #
    # In ActiveRecord, these automated events are run in the following order:
    # * before validation - Run before callbacks and persist new states, then validate
    # * before save - If validation was skipped, run before callbacks and persist new states, then save
    # * after save - Run after callbacks
    #
    # For example,
    #
    #   vehicle = Vehicle.create          # => #<Vehicle id: 1, name: nil, state: "parked">
    #   vehicle.state_event               # => nil
    #   vehicle.state_event = 'invalid'
    #   vehicle.valid?                    # => false
    #   vehicle.errors.full_messages      # => ["State event is invalid"]
    #
    #   vehicle.state_event = 'ignite'
    #   vehicle.valid?                    # => true
    #   vehicle.save                      # => true
    #   vehicle.state                     # => "idling"
    #   vehicle.state_event               # => nil
    #
    # Note that this can also be done on a mass-assignment basis:
    #
    #   vehicle = Vehicle.create(:state_event => 'ignite')  # => #<Vehicle id: 1, name: nil, state: "idling">
    #   vehicle.state                                       # => "idling"
    #
    # This technique is always used for transitioning states when the +save+
    # action (which is the default) is configured for the machine.
    #
    # === Security implications
    #
    # Beware that public event attributes mean that events can be fired
    # whenever mass-assignment is being used. If you want to prevent malicious
    # users from tampering with events through URLs / forms, you should use
    # Rails' strong parameters to control which attributes are permitted:
    #
    #   class VehiclesController < ApplicationController
    #     def vehicle_params
    #       params.require(:vehicle).permit(:color, :make, :model)
    #       # Exclude state_event to prevent tampering
    #     end
    #   end
    #
    # If you want to only have *some* events be able to fire via mass-assignment,
    # you can build two state machines (one public and one protected) like so:
    #
    #   class Vehicle < ApplicationRecord
    #     # Define private machine
    #     state_machine do
    #       # Define private events here
    #     end
    #
    #     # Public machine targets the same state as the private machine
    #     state_machine :public_state, :attribute => :state do
    #       # Define public events here
    #     end
    #
    #     # Control access via strong parameters in your controller
    #   end
    #
    # == Transactions
    #
    # In order to ensure that any changes made during transition callbacks
    # are rolled back during a failed attempt, every transition is wrapped
    # within a transaction.
    #
    # For example,
    #
    #   class Message < ApplicationRecord
    #   end
    #
    #   Vehicle.state_machine do
    #     before_transition do |vehicle, transition|
    #       Message.create(:content => transition.inspect)
    #       false
    #     end
    #   end
    #
    #   vehicle = Vehicle.create      # => #<Vehicle id: 1, name: nil, state: "parked">
    #   vehicle.ignite                # => false
    #   Message.count                 # => 0
    #
    # *Note* that only before callbacks that halt the callback chain and
    # failed attempts to save the record will result in the transaction being
    # rolled back.  If an after callback halts the chain, the previous result
    # still applies and the transaction is *not* rolled back.
    #
    # To turn off transactions:
    #
    #   class Vehicle < ApplicationRecord
    #     state_machine :initial => :parked, :use_transactions => false do
    #       ...
    #     end
    #   end
    #
    # == Validations
    #
    # As mentioned in StateMachines::Machine#state, you can define behaviors,
    # like validations, that only execute for certain states. One *important*
    # caveat here is that, due to a constraint in ActiveRecord's validation
    # framework, custom validators will not work as expected when defined to run
    # in multiple states.  For example:
    #
    #   class Vehicle < ApplicationRecord
    #     state_machine do
    #       ...
    #       state :first_gear, :second_gear do
    #         validate :speed_is_legal
    #       end
    #     end
    #   end
    #
    # In this case, the <tt>:speed_is_legal</tt> validation will only get run
    # for the <tt>:second_gear</tt> state.  To avoid this, you can define your
    # custom validation like so:
    #
    #   class Vehicle < ApplicationRecord
    #     state_machine do
    #       ...
    #       state :first_gear, :second_gear do
    #         validate {|vehicle| vehicle.speed_is_legal}
    #       end
    #     end
    #   end
    #
    # == Validation errors
    #
    # If an event fails to successfully fire because there are no matching
    # transitions for the current record, a validation error is added to the
    # record's state attribute to help in determining why it failed and for
    # reporting via the UI.
    #
    # For example,
    #
    #   vehicle = Vehicle.create(:state => 'idling')  # => #<Vehicle id: 1, name: nil, state: "idling">
    #   vehicle.ignite                                # => false
    #   vehicle.errors.full_messages                  # => ["State cannot transition via \"ignite\""]
    #
    # If an event fails to fire because of a validation error on the record and
    # *not* because a matching transition was not available, no error messages
    # will be added to the state attribute.
    #
    # In addition, if you're using the <tt>ignite!</tt> version of the event,
    # then the failure reason (such as the current validation errors) will be
    # included in the exception that gets raised when the event fails.  For
    # example, assuming there's a validation on a field called +name+ on the class:
    #
    #   vehicle = Vehicle.new
    #   vehicle.ignite!       # => StateMachines::InvalidTransition: Cannot transition state via :ignite from :parked
    #                              # (Reason(s): Name cannot be blank)
    #
    # == Scopes
    #
    # To assist in filtering models with specific states, a series of scopes
    # are defined on the model for finding records with or without a
    # particular set of states.
    #
    # These scopes are essentially the functional equivalent of the
    # following definitions:
    #
    #   class Vehicle < ApplicationRecord
    #     # with_states also aliased to with_state
    #     scope :with_states, ->(states) { states.present? ? where(state: states) : all }
    #
    #     # without_states also aliased to without_state
    #     scope :without_states, ->(states) { states.present? ? where.not(state: states) : all }
    #   end
    #
    # *Note*, however, that the states are converted to their stored values
    # before being passed into the query.
    #
    # Because of the way scopes work in ActiveRecord, they can be
    # chained like so:
    #
    #   Vehicle.with_state(:parked).order(id: :desc)
    #
    # Note that states can also be referenced by the string version of their
    # name:
    #
    #   Vehicle.with_state('parked')
    #
    # === Transparent Scopes
    #
    # When `nil` is passed to any of the state scopes, they return `all` records
    # without applying any filters. This allows for more flexible scope chaining
    # in search interfaces:
    #
    #   Vehicle.with_state(params[:state])  # Returns all vehicles if params[:state] is nil
    #   Vehicle.where(color: 'red').with_state(nil)  # Returns all red vehicles
    #
    # == Callbacks
    #
    # All before/after transition callbacks defined for ActiveRecord models
    # behave in the same way that other ActiveRecord callbacks behave.  The
    # object involved in the transition is passed in as an argument.
    #
    # For example,
    #
    #   class Vehicle < ApplicationRecord
    #     state_machine :initial => :parked do
    #       before_transition any => :idling do |vehicle|
    #         vehicle.put_on_seatbelt
    #       end
    #
    #       before_transition do |vehicle, transition|
    #         # log message
    #       end
    #
    #       event :ignite do
    #         transition :parked => :idling
    #       end
    #     end
    #
    #     def put_on_seatbelt
    #       ...
    #     end
    #   end
    #
    # Note, also, that the transition can be accessed by simply defining
    # additional arguments in the callback block.
    #
    # === Failure callbacks
    #
    # +after_failure+ callbacks allow you to execute behaviors when a transition
    # is allowed, but fails to save.  This could be useful for something like
    # auditing transition attempts.  Since callbacks run within transactions in
    # ActiveRecord, a save failure will cause any records that get created in
    # your callback to roll back.  You can work around this issue like so:
    #
    #   class TransitionLog < ApplicationRecord
    #     connects_to database: { writing: :primary, reading: :primary }
    #   end
    #
    #   class Vehicle < ApplicationRecord
    #     state_machine do
    #       after_failure do |vehicle, transition|
    #         TransitionLog.create(:vehicle => vehicle, :transition => transition)
    #       end
    #
    #       ...
    #     end
    #   end
    #
    # The +TransitionLog+ model establishes a separate connection to the database
    # that allows new records to be saved without being affected by rollbacks
    # in the +Vehicle+ model's transaction.
    #
    # === Callback Order
    #
    # Callbacks occur in the following order.  Callbacks specific to state_machine
    # are bolded.  The remaining callbacks are part of ActiveRecord.
    #
    # * (-) save
    # * (-) begin transaction (if enabled)
    # * (1) *before_transition*
    # * (-) valid
    # * (2) before_validation
    # * (-) validate
    # * (3) after_validation
    # * (4) before_save
    # * (5) before_create
    # * (-) create
    # * (6) after_create
    # * (7) after_save
    # * (8) *after_transition*
    # * (-) end transaction (if enabled)
    # * (9) after_commit
    #
    # == Internationalization
    #
    # Any error message that is generated from performing invalid
    # transitions can be localized.  The following default translations are used:
    #
    #   en:
    #     activerecord:
    #       errors:
    #         messages:
    #           invalid: "is invalid"
    #           # %{value} = attribute value, %{state} = Human state name
    #           invalid_event: "cannot transition when %{state}"
    #           # %{value} = attribute value, %{event} = Human event name, %{state} = Human current state name
    #           invalid_transition: "cannot transition via %{event}"
    #
    # You can override these for a specific model like so:
    #
    #   en:
    #     activerecord:
    #       errors:
    #         models:
    #           user:
    #             invalid: "is not valid"
    #
    # In addition to the above, you can also provide translations for the
    # various states / events in each state machine.  Using the Vehicle example,
    # state translations will be looked for using the following keys, where
    # +model_name+ = "vehicle", +machine_name+ = "state" and +state_name+ = "parked":
    # * <tt>activerecord.state_machines.#{model_name}.#{machine_name}.states.#{state_name}</tt>
    # * <tt>activerecord.state_machines.#{model_name}.states.#{state_name}</tt>
    # * <tt>activerecord.state_machines.#{machine_name}.states.#{state_name}</tt>
    # * <tt>activerecord.state_machines.states.#{state_name}</tt>
    #
    # Event translations will be looked for using the following keys, where
    # +model_name+ = "vehicle", +machine_name+ = "state" and +event_name+ = "ignite":
    # * <tt>activerecord.state_machines.#{model_name}.#{machine_name}.events.#{event_name}</tt>
    # * <tt>activerecord.state_machines.#{model_name}.events.#{event_name}</tt>
    # * <tt>activerecord.state_machines.#{machine_name}.events.#{event_name}</tt>
    # * <tt>activerecord.state_machines.events.#{event_name}</tt>
    #
    # An example translation configuration might look like so:
    #
    #   es:
    #     activerecord:
    #       state_machines:
    #         states:
    #           parked: 'estacionado'
    #         events:
    #           park: 'estacionarse'
    module ActiveRecord
      include Base
      include ActiveModel

      # The default options to use for state machines using this integration
      @defaults = { action: :save, use_transactions: true }

      # Machine-specific methods for enum integration
      module MachineMethods
        # Enum integration metadata storage
        attr_accessor :enum_integration

        # Hook called after machine initialization
        def after_initialize
          super
          initialize_enum_integration
        end

        # Check if enum integration should be enabled for this machine
        def detect_enum_integration
          return nil unless owner_class.defined_enums.key?(attribute.to_s)

          # For now, auto-detect enum and enable basic integration
          # Later we can add explicit configuration options
          {
            enabled: true,
            prefix: true,
            suffix: false,
            scopes: true,
            enum_values: owner_class.defined_enums[attribute.to_s] || {},
            original_enum_methods: detect_existing_enum_methods,
            state_machine_methods: []
          }
        end

        # Initialize enum integration if enum is detected
        def initialize_enum_integration
          detected_config = detect_enum_integration
          return unless detected_config

          # Store enum integration metadata
          self.enum_integration = detected_config
        end

        # Override state method to trigger method generation after states are defined
        def state(*, &)
          result = super

          # Generate methods after each state addition if enum integration is enabled
          generate_state_machine_methods if enum_integrated?

          result
        end

        # Check if this machine has enum integration enabled
        def enum_integrated?
          enum_integration && enum_integration[:enabled]
        end

        # Get the enum mapping for this attribute
        def enum_mapping
          return {} unless enum_integrated?

          enum_integration[:enum_values] || {}
        end

        # Get list of original enum methods that were preserved
        def original_enum_methods
          return [] unless enum_integrated?

          enum_integration[:original_enum_methods] || []
        end

        # Get list of state machine methods that were generated
        def state_machine_methods
          return [] unless enum_integrated?

          enum_integration[:state_machine_methods] || []
        end

        private

        # Detect existing enum methods for this attribute
        def detect_existing_enum_methods
          return [] unless owner_class.defined_enums.key?(attribute.to_s)

          enum_values = owner_class.defined_enums[attribute.to_s]
          methods = []

          enum_values.each_key do |value|
            # Predicate methods like 'active?'
            predicate = "#{value}?"
            methods << predicate if owner_class.method_defined?(predicate)

            # Bang methods like 'active!'
            bang_method = "#{value}!"
            methods << bang_method if owner_class.method_defined?(bang_method)

            # Scope methods (class-level)
            methods << value.to_s if owner_class.respond_to?(value)
            methods << "not_#{value}" if owner_class.respond_to?("not_#{value}")
          end

          methods
        end

        # Generate method name with prefix/suffix based on configuration
        def generate_state_method_name(state_name, method_type)
          return state_name unless enum_integrated?

          config = enum_integration
          base_name = case method_type
                      when :predicate
                        "#{state_name}?"
                      when :bang
                        "#{state_name}!"
                      else
                        state_name.to_s
                      end

          # Apply prefix
          if config[:prefix]
            prefix = config[:prefix] == true ? "#{attribute}_" : "#{config[:prefix]}_"
            base_name = "#{prefix}#{base_name}"
          end

          # Apply suffix
          if config[:suffix]
            suffix = config[:suffix] == true ? "_#{attribute}" : "_#{config[:suffix]}"
            base_name = base_name.gsub(/(\?|!)$/, "#{suffix}\\1")
            base_name = "#{base_name}#{suffix}" unless base_name.end_with?('?', '!')
          end

          base_name
        end

        # Generate state machine methods with conflict resolution
        def generate_state_machine_methods
          return unless enum_integrated?

          # Initialize tracking if not already done
          @processed_states ||= Set.new
          enum_integration[:state_machine_methods] ||= []

          # Get all states for this machine
          states.each do |state|
            state_name = state.name.to_s
            next if state.nil? # Skip nil state
            next if @processed_states.include?(state_name) # Skip already processed states

            # Generate predicate method (e.g., status_pending?)
            predicate_method = generate_state_method_name(state_name, :predicate)
            if predicate_method != "#{state_name}?"
              define_state_predicate_method(state_name, predicate_method)
              track_generated_method(predicate_method)
            end

            # Generate bang method (e.g., status_pending!)
            bang_method = generate_state_method_name(state_name, :bang)
            if bang_method != "#{state_name}!"
              define_state_bang_method(state_name, bang_method)
              track_generated_method(bang_method)
            end

            # Generate scope methods (e.g., status_pending) if scopes are enabled
            if enum_integration[:scopes]
              scope_method = generate_state_method_name(state_name, :scope)
              if scope_method != state_name
                define_state_scope_method(state_name, scope_method)
                track_generated_method(scope_method)
              end
            end

            # Mark this state as processed
            @processed_states.add(state_name)
          end
        end

        # Define a prefixed predicate method for a state
        def define_state_predicate_method(state_name, method_name)
          machine_attribute = attribute
          target_state_name = state_name.to_sym
          owner_class.define_method(method_name) do
            machine = self.class.state_machine(machine_attribute)
            machine.states.matches?(self, target_state_name)
          end
        end

        # Define a prefixed bang method for a state
        def define_state_bang_method(state_name, method_name)
          owner_class.define_method(method_name) do
            # Raise an error with actionable guidance
            raise "#{method_name} is a conflict-resolution placeholder. " \
                  "Use the original enum method '#{state_name}!' or state machine events instead."
          end
        end

        # Define a prefixed scope method for a state
        def define_state_scope_method(state_name, method_name)
          machine_attribute = attribute
          scope_lambda = lambda do |value = true|
            machine = state_machine(machine_attribute)
            state_value = machine.states[state_name.to_sym].value
            if value
              where(machine_attribute => state_value)
            else
              where.not(machine_attribute => state_value)
            end
          end

          owner_class.define_singleton_method(method_name, &scope_lambda)
          owner_class.define_singleton_method("not_#{method_name}") do
            public_send(method_name, false)
          end
        end

        # Track generated state machine methods for introspection
        def track_generated_method(method_name)
          return unless enum_integrated?

          # Use a Set to ensure no duplicates
          enum_integration[:state_machine_methods] ||= []
          return if enum_integration[:state_machine_methods].include?(method_name)

          enum_integration[:state_machine_methods] << method_name
        end
      end

      # Include MachineMethods to make enum integration methods available on machine instances
      include MachineMethods

      class << self
        # Classes that inherit from ActiveRecord::Base will automatically use
        # the ActiveRecord integration.
        def matching_ancestors
          [::ActiveRecord::Base]
        end
      end

      protected

      # Only runs validations on the action if using <tt>:save</tt>
      def runs_validations_on_action?
        action == :save
      end

      # Gets the db default for the machine's attribute
      def owner_class_attribute_default
        return unless owner_class.connected? && owner_class.table_exists?

        owner_class.column_defaults[attribute.to_s]
      end

      def define_state_initializer
        define_helper :instance, <<-END_EVAL, __FILE__, __LINE__ + 1
          def initialize(attributes = nil, *)
            super(attributes) do |*args|
              attributes = (attributes || {}).transform_keys { |key| self.class.attribute_aliases[key.to_s] || key }
              scoped_attributes = attributes.merge(self.class.scope_attributes)

              self.class.state_machines.initialize_states(self, {}, scoped_attributes)
              yield(*args) if block_given?
            end
          end
        END_EVAL
      end

      # Uses around callbacks to run state events if using the :save hook
      def define_action_hook
        if action_hook == :save
          define_helper :instance, <<-END_EVAL, __FILE__, __LINE__ + 1
              def save(*, **)
                self.class.state_machine(#{name.inspect}).send(:around_save, self) { super }
              end

              def save!(*, **)
                result = self.class.state_machine(#{name.inspect}).send(:around_save, self) { super }
                result || raise(ActiveRecord::RecordInvalid.new(self))
              end

              def changed_for_autosave?
                super || self.class.state_machines.any? {|name, machine| machine.action == :save && machine.read(self, :event)}
              end
          END_EVAL
        else
          super
        end
      end

      # Runs state events around the machine's :save action
      def around_save(object, &)
        # Pass fiber: false to avoid deadlocks with ActiveRecord's LoadInterlockAwareMonitor
        object.class.state_machines.transitions(object, action, fiber: false).perform(&)
      end

      # Creates a scope for finding records *with* a particular state or
      # states for the attribute
      def create_with_scope(_name)
        attr_name = attribute
        lambda do |klass, values|
          if values.present?
            klass.where(attr_name => values)
          else
            klass.all
          end
        end
      end

      # Creates a scope for finding records *without* a particular state or
      # states for the attribute
      def create_without_scope(_name)
        attr_name = attribute
        lambda do |klass, values|
          if values.present?
            klass.where.not(attr_name => values)
          else
            klass.all
          end
        end
      end

      # Runs a new database transaction, rolling back any changes by raising
      # an ActiveRecord::Rollback exception if the yielded block fails
      # (i.e. returns false).
      def transaction(object)
        result = nil
        object.class.transaction do
          raise ::ActiveRecord::Rollback unless (result = yield)
        end
        result
      end

      def locale_path
        "#{File.dirname(__FILE__)}/active_record/locale.rb"
      end

      private

      # Generates the results for the given scope based on one or more states to filter by
      def run_scope(scope, machine, klass, states)
        values = states.flatten.compact.map { |state| machine.states.fetch(state).value }
        scope.call(klass, values)
      end

      # ActiveModel's use of method_missing / respond_to for attribute methods
      # breaks both ancestor lookups and defined?(super).  Need to special-case
      # the existence of query attribute methods.
      def owner_class_ancestor_has_method?(scope, method)
        scope == :instance && method == "#{attribute}?" ? owner_class : super
      end
    end
    register(ActiveRecord)
  end
end
