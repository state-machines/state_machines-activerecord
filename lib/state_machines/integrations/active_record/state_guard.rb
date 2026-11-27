# frozen_string_literal: true

require 'state_machines/integrations/active_record/errors'

module StateMachines
  module Integrations
    module ActiveRecord
      # Enforces that state changes through the model are event-only, for
      # machines declared with <tt>direct_assignment: :deny</tt> (or all
      # machines when ActiveRecord.direct_assignment is +:deny+). Machines
      # allowing direct assignment (the default) are left alone.
      #
      # Every write of a machine's attribute through the model (setter, mass
      # assignment, attribute alias, +record[:attr] =+, +write_attribute+) is
      # checked before the value changes:
      #
      # * writes performed by the machine itself (initialization, a
      #   transition persisting its destination, a rollback) are authorized
      #   for the duration of that single write only, so callbacks running
      #   around a transition cannot overwrite the state;
      # * assigning the value the record already holds (compared through the
      #   attribute's type, so +:parked+, +'parked'+ and an integer-backed
      #   +0+ are the same) is allowed and runs nothing;
      # * anything else raises {StateMachines::DirectStateAssignment}.
      #
      # While a record is being built, assigned states are collected and,
      # once the machines have initialized, must equal the initial state.
      #
      # As a backstop, saving a record whose state attribute changed without
      # an authorized write (e.g. an in-place mutation or a write straight to
      # the attribute set) raises the same error.
      #
      # Raw persistence (+update_column(s)+, +update_all+, +insert_all+,
      # SQL) and database hydration / +reload+ never go through attribute
      # writers and are left alone.
      module StateGuard
        # Names of attributes the machine is currently writing
        AUTHORIZED_WRITES = :@_state_machines_authorized_writes

        # Attribute name => last state value written by the machine
        AUTHORIZED_STATES = :@_state_machines_authorized_states

        # Attribute names assigned while the record is being built
        CONSTRUCTION_WRITES = :@_state_machines_construction_writes

        # Instance methods mixed into every model owning a state machine.
        module RecordMethods
          # Updates an attribute, refusing a direct change of a state machine
          # attribute.
          #
          # @param attr_name [String, Symbol] attribute (or alias) name
          # @param value [Object] the new value
          # @raise [StateMachines::DirectStateAssignment]
          def write_attribute(attr_name, value)
            name = attr_name.to_s
            StateGuard.check_write!(self, self.class.attribute_aliases[name] || name, value)
            super
          end

          # @api private
          # @see #write_attribute
          def _write_attribute(attr_name, value)
            StateGuard.check_write!(self, attr_name.to_s, value)
            super
          end

          # Converts the record to another class, preserving its state.
          #
          # No transition callbacks run, and a state changed without an event
          # stays unauthorized on the new instance.
          #
          # @param klass [Class] the class to convert to
          # @return [ActiveRecord::Base] the converted record
          # @raise [StateMachines::PendingStateEvent] while an event attribute
          #   or a transition prepared by validation is queued
          def becomes(klass)
            StateGuard.ensure_no_queued_work!(self)
            super.tap { |became| StateGuard.copy_authorizations(self, became) }
          end

          # Duplicates the record with its state. Dirty tracking restarts on
          # the copy, so the states the original holds legitimately are
          # authorized on it; a state changed without an event is not.
          #
          # @param other [ActiveRecord::Base] the original record
          # @return [void]
          def initialize_dup(other)
            legitimate = StateGuard.legitimate_states(other)
            super
            remove_instance_variable(AUTHORIZED_WRITES) if instance_variable_defined?(AUTHORIZED_WRITES)
            instance_variable_set(AUTHORIZED_STATES, legitimate)
          end

          # Reloads the record, forgetting state authorizations: the reloaded
          # attributes are the database's.
          #
          # @return [ActiveRecord::Base] the reloaded record
          def reload(*)
            super.tap { StateGuard.forget(self) }
          end

          # Forgets state authorizations once changes are persisted.
          #
          # @return [void]
          def changes_applied
            super
            StateGuard.forget(self)
          end

          # Forgets state authorizations along with the dirty tracking.
          #
          # @return [void]
          def clear_changes_information
            super
            StateGuard.forget(self)
          end

          private

          # @see #write_attribute
          def attribute=(attr_name, value)
            StateGuard.check_write!(self, attr_name.to_s, value)
            super
          end

          # Saves, first refusing state changes made without an event.
          def create_or_update(...)
            StateGuard.verify_persistable!(self)
            super
          end

          # Checks again once +before_save+ callbacks have run.
          def _create_record(...)
            StateGuard.verify_persistable!(self)
            super
          end

          # Checks again once +before_save+ callbacks have run.
          def _update_record(...)
            StateGuard.verify_persistable!(self)
            super
          end

          # Restoring an attribute to its database value is a revert, not a
          # state change, so the write is authorized.
          def restore_attribute!(attr_name)
            StateGuard.authorize(self, attr_name.to_s) { super }
          end

          # Forgets the authorization of an attribute whose change is cleared
          # (e.g. by +update_columns+).
          def clear_attribute_change(attr_name)
            super
            StateGuard.forget(self, attr_name.to_s)
          end
        end

        # Guards the writers of machine attributes: the attribute itself,
        # the column it aliases and every alias of that column, whether an
        # ActiveRecord attribute or not (e.g. +attr_accessor+).
        class WriterGuard < Module
          # @return [Set<String>] the attributes whose writers are guarded,
          #   aliases resolved
          attr_reader :targets

          def initialize
            super
            @targets = Set.new
            @writers = Set.new
          end

          # Guards the writer of +name+.
          #
          # @param name [String] an attribute or alias name
          # @return [void]
          def guard(name)
            return unless @writers.add?(name)

            define_method(:"#{name}=") do |value|
              StateGuard.check_write!(self, self.class.attribute_aliases[name] || name, value)
              super(value)
            end
          end
        end

        # Guards writers of aliases declared after the machine.
        module AliasGuard
          # @see ActiveRecord::AttributeMethods::ClassMethods#alias_attribute
          def alias_attribute(new_name, old_name)
            super.tap do
              guard = StateGuard.writer_guard(self)
              target = attribute_aliases.fetch(old_name.to_s, old_name.to_s)
              guard.guard(new_name.to_s) if guard&.targets&.include?(target)
            end
          end
        end

        class << self
          # Installs the guard on a model class for a machine.
          #
          # @param klass [Class] the model class
          # @param attribute [Symbol] the machine's attribute
          # @return [void]
          def install(klass, attribute)
            klass.include(RecordMethods) unless klass < RecordMethods
            klass.singleton_class.prepend(AliasGuard) unless klass.singleton_class < AliasGuard
            guard = writer_guard(klass) || WriterGuard.new.tap { |mod| klass.prepend(mod) }

            name = attribute.to_s
            target = klass.attribute_aliases.fetch(name, name)
            guard.targets << target
            [name, target, *klass.attribute_aliases.select { |_, aliased| aliased == target }.keys]
              .each { |writer| guard.guard(writer) }
          end

          # @param klass [Class] a model class
          # @return [WriterGuard, nil] the writer guard of the class
          def writer_guard(klass)
            klass.ancestors.find { |mod| mod.is_a?(WriterGuard) }
          end

          # Checks a write of attribute +name+ before it happens.
          #
          # @param record [ActiveRecord::Base] the record being written
          # @param name [String] the attribute name, aliases resolved
          # @param value [Object] the value being written
          # @return [void]
          # @raise [StateMachines::DirectStateAssignment] when the write
          #   changes the state of a machine without authorization
          def check_write!(record, name, value)
            machine = machine_for(record, name)
            return unless machine
            return if record.instance_variable_get(AUTHORIZED_WRITES)&.include?(name)

            if (writes = record.instance_variable_get(CONSTRUCTION_WRITES))
              writes << name
              return
            end

            current = current_value(record, machine)
            return if same_state?(record, machine, current, value)

            raise DirectStateAssignment.new(record, machine: machine, from: current, to: value)
          end

          # Authorizes writes of attribute +name+ for the duration of the
          # block, then remembers the written value as legitimate.
          #
          # @param record [ActiveRecord::Base] the record being written
          # @param name [String] the attribute name, aliases resolved
          # @return [Object] the block's result
          def authorize(record, name)
            writes = record.instance_variable_get(AUTHORIZED_WRITES) ||
                     record.instance_variable_set(AUTHORIZED_WRITES, Set.new)
            added = writes.add?(name)
            result = yield
            machine = machine_for(record, name)
            remember(record, name, current_value(record, machine)) if machine
            result
          ensure
            writes.delete(name) if added
          end

          # Starts collecting state assignments made while building a record.
          #
          # @param record [ActiveRecord::Base] the record being built
          # @return [void]
          def begin_construction(record)
            record.instance_variable_set(CONSTRUCTION_WRITES, Set.new)
          end

          # Stops collecting state assignments and checks that each assigned
          # state equals the machine's initial state for the record (static,
          # dynamic or schema-default).
          #
          # @param record [ActiveRecord::Base] the record being built
          # @return [void]
          # @raise [StateMachines::DirectStateAssignment] when a state other
          #   than the initial one was assigned
          def finish_construction(record)
            writes = record.instance_variable_get(CONSTRUCTION_WRITES)
            record.instance_variable_set(CONSTRUCTION_WRITES, nil)
            return if writes.nil? || writes.empty?

            # Machines sharing an attribute (e.g. a public and a private
            # machine) share its initial state, set on one of them
            machines = record.class.state_machines.values.group_by { |machine| guarded_name(machine) }
            machines.slice(*writes).each do |name, siblings|
              machine = siblings.find { |sibling| sibling.initial_state(record) } || siblings.first
              current = current_value(record, machine)
              expected = machine.initial_state(record)&.value
              next remember(record, name, current) if same_state?(record, machine, expected, current)

              raise DirectStateAssignment.new(record, machine: machine, from: expected, to: current)
            end
          end

          # Refuses to persist a state attribute that changed without an
          # authorized write.
          #
          # @param record [ActiveRecord::Base] the record being saved
          # @return [void]
          # @raise [StateMachines::DirectStateAssignment]
          def verify_persistable!(record)
            each_persisted_state(record) do |machine, name, current, legitimate|
              next if legitimate

              from = record.attribute_in_database(name)
              raise DirectStateAssignment.new(record, machine: machine, from: from, to: current)
            end
          end

          # The persisted state attributes whose current value the record
          # holds legitimately: unchanged, or last written by the machine.
          #
          # @param record [ActiveRecord::Base]
          # @return [Hash{String => Object}] attribute name => current value
          def legitimate_states(record)
            states = {}
            each_persisted_state(record) { |_machine, name, current, legitimate| states[name] = current if legitimate }
            states
          end

          # Like {verify_persistable!}, but only while some machine has an
          # event queued, so no transition starts from an unauthorized state.
          #
          # @param record [ActiveRecord::Base] the record about to transition
          # @return [void]
          def verify_before_transitions!(record)
            verify_persistable!(record) if queued_work(record)
          end

          # @param record [ActiveRecord::Base] the record being converted or forced
          # @param operation [String] the refused method, named in the error
          # @return [void]
          # @raise [StateMachines::PendingStateEvent] when an event attribute
          #   or a prepared transition is queued
          def ensure_no_queued_work!(record, operation: 'becomes')
            machine, event = queued_work(record)
            raise PendingStateEvent.new(record, machine, event, operation: operation) if machine
          end

          # Gives +target+ the same state authorizations as +source+.
          #
          # @return [void]
          def copy_authorizations(source, target)
            target.instance_variable_set(AUTHORIZED_STATES, source.instance_variable_get(AUTHORIZED_STATES)&.dup)
          end

          # Forgets the remembered state of one or every attribute.
          #
          # @param record [ActiveRecord::Base]
          # @param name [String, nil] the attribute, or nil for all
          # @return [void]
          def forget(record, name = nil)
            authorized = record.instance_variable_get(AUTHORIZED_STATES)
            return unless authorized

            name ? authorized.delete(name) : authorized.clear
          end

          # The attribute a machine writes, aliases resolved.
          #
          # @param machine [StateMachines::Machine]
          # @return [String]
          def guarded_name(machine)
            name = machine.attribute.to_s
            machine.owner_class.attribute_aliases.fetch(name, name)
          end

          private

          # Yields each database-backed state attribute of the record with
          # its current value and whether the record holds it legitimately.
          #
          # @yieldparam machine [StateMachines::Machine]
          # @yieldparam name [String] the attribute name, aliases resolved
          # @yieldparam current [Object] the current value
          # @yieldparam legitimate [Boolean] unchanged, or last written by
          #   the machine
          # @return [void]
          def each_persisted_state(record)
            authorized = record.instance_variable_get(AUTHORIZED_STATES)
            seen = Set.new

            record.class.state_machines.each_value do |machine|
              next unless machine.direct_assignment_denied?

              name = guarded_name(machine)
              next unless seen.add?(name) && record._has_attribute?(name) && !machine.transient_attribute?(record.class)

              current = record._read_attribute(name)
              legitimate = !record.attribute_changed?(name) ||
                           (authorized&.key?(name) && same_state?(record, machine, authorized[name], current))
              yield machine, name, current, legitimate
            end
          end

          # @return [StateMachines::Machine, nil] the first machine writing
          #   attribute +name+ that denies direct assignment
          def machine_for(record, name)
            record.class.state_machines.each_value.find do |machine|
              machine.direct_assignment_denied? && guarded_name(machine) == name
            end
          end

          # @return [Array(StateMachines::Machine, Object), nil] the first
          #   machine with queued work and its event
          def queued_work(record)
            record.class.state_machines.each_value do |machine|
              next unless machine.action

              event = machine.read(record, :event)
              event ||= machine.read(record, :event_transition, true)&.event
              return [machine, event] if event
            end
            nil
          end

          # @return [Object] the current value of the machine's attribute
          def current_value(record, machine)
            name = guarded_name(machine)
            record._has_attribute?(name) ? record._read_attribute(name) : record.public_send(machine.attribute)
          end

          # Whether two values denote the same stored state, compared through
          # the attribute's type (symbols and strings, integer-backed states,
          # enums).
          #
          # @return [Boolean]
          def same_state?(record, machine, left, right)
            canonical(record, machine, left) == canonical(record, machine, right)
          end

          # @return [Object] the value as the attribute would store it
          def canonical(record, machine, value)
            name = guarded_name(machine)
            if record._has_attribute?(name)
              record.class.type_for_attribute(name).cast(value)
            else
              value.is_a?(Symbol) ? value.to_s : value
            end
          end

          # Remembers +value+ as the legitimate state of attribute +name+.
          #
          # @return [void]
          def remember(record, name, value)
            authorized = record.instance_variable_get(AUTHORIZED_STATES) ||
                         record.instance_variable_set(AUTHORIZED_STATES, {})
            authorized[name] = value
          end
        end
      end
    end
  end
end
