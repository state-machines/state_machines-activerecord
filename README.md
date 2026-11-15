[![Build Status](https://github.com/state-machines/state_machines-activerecord/actions/workflows/ruby.yml/badge.svg)](https://github.com/state-machines/state_machines-activerecord/actions/workflows/ruby.yml)

# StateMachines Active Record Integration

The Active Record 8.0+ integration adds support for database transactions, automatically
saving the record, named scopes, validation errors.

## Requirements

- Ruby 3.2+
- Rails 8.0+

## Installation

Add this line to your application's Gemfile:

    gem 'state_machines-activerecord'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install state_machines-activerecord

## Usage

For the complete usage guide, see http://www.rubydoc.info/github/state-machines/state_machines-activerecord/StateMachines/Integrations/ActiveRecord

### Example

```ruby
class Vehicle < ApplicationRecord
  state_machine :initial => :parked do
    before_transition :parked => any - :parked, :do => :put_on_seatbelt
    after_transition any => :parked do |vehicle, transition|
      vehicle.seatbelt = 'off'
    end
    around_transition :benchmark

    event :ignite do
      transition :parked => :idling
    end

    state :first_gear, :second_gear do
      validates :seatbelt_on, presence: true
    end
  end

  def put_on_seatbelt
    ...
  end

  def benchmark
    ...
    yield
    ...
  end
end
```

## State changes go through events

Opt a machine in with `direct_assignment: :deny`:

```ruby
class Vehicle < ActiveRecord::Base
  state_machine initial: :parked, direct_assignment: :deny do
    event(:ignite) { transition parked: :idling }
  end
end
```

Machines without the option use
`StateMachines::Integrations::ActiveRecord.direct_assignment`, which is
`:allow` (the attribute can be written directly). Set it to `:deny` in an
initializer to opt every machine in; a machine can still pass
`direct_assignment: :allow`. The default is read when a machine is defined,
so set it before your models load.

With `:deny`, the only way to change a record's state through the model is an event:

```ruby
vehicle.ignite                  # fire it
vehicle.ignite!                 # fire it, raising on refusal
vehicle.state_event = 'ignite'  # queue it for the next save
vehicle.save
vehicle.update(state_event: 'ignite')
```

Writing a *different* state directly raises
`StateMachines::DirectStateAssignment` before the value changes, whichever
writer is used: `state=`, mass assignment (`assign_attributes`, `new`,
`create`, `update`), an attribute alias, `record[:state] =`,
`write_attribute`, `update_attribute`, or a Rails enum bang method
(`processing!`). Assigning the state the record already holds (`:parked`,
`"parked"`, or the stored integer for integer-backed machines) is allowed and
runs nothing. The error names the machine, the attribute, both values, and
the alternatives below; a refused assignment is not an event refusal, so no
`<event>_refusal` reason is recorded.

```ruby
vehicle = Vehicle.create!        # parked
vehicle.state = 'idling'         # => StateMachines::DirectStateAssignment
vehicle.update(state: 'idling', state_event: 'ignite')
                                 # => StateMachines::DirectStateAssignment
```

- New records can be built with their initial state (static, dynamic, or the
  schema default), e.g. `Vehicle.new(state: 'parked')`, but not with another
  one: `Vehicle.create!(state: 'idling')`, `create_with(state: 'idling')` and
  an initializer block writing `idling` all raise.
- Callbacks are held to the same rule: a `before_transition`,
  `after_transition`, `before_save` or `after_initialize` writing the state
  raises. Only the machine's own writes (initialization, the transition's
  write, rollback after a failure) are authorized, each for that single
  write. Loading from the database, `reload`, `restore_attributes`, `dup`
  and `becomes` keep the state they hold.
- As a backstop, `save`, `save!`, `save(validate: false)` and
  `update_attribute` refuse to persist a state that changed without going
  through the setter (an in-place mutation, a write to the attribute set),
  and no queued event runs from such a state.
- `becomes` preserves the state without running transition callbacks, and
  raises `StateMachines::PendingStateEvent` while an event attribute or a
  transition prepared by validation is still queued.

### Forms

Expose events, not states. Permit the event attribute and leave the state
attribute out of strong parameters:

```ruby
def vehicle_params
  params.require(:vehicle).permit(:name, :state_event)
end
```

A form submitting `state` alongside (or instead of) `state_event` gets a
`DirectStateAssignment` instead of a silent state change.

### Data repair

Raw persistence stays outside the state machine on purpose: no event is
inferred, no callback or validation runs.

```ruby
vehicle.update_column(:state, 'idling')
Vehicle.where(id: ids).update_all(state: 'parked')
Vehicle.upsert_all(rows)
ActiveRecord::Base.connection.execute("UPDATE vehicles SET state = 'parked' WHERE ...")
```

Other instances already loaded in memory keep their old state until you
`reload` them.

### Initial state from the schema default

When a machine has no `initial:` option and its attribute has a schema
default (a database column default, or an Attributes API `default:`) that
names a defined state, that default is the initial state:

```ruby
# db/schema.rb
create_table "accounts" do |t|
  t.string "state", default: "active", null: false
end

class Account < ApplicationRecord
  state_machine do
    state :active, :suspended
    event(:suspend) { transition active: :suspended }
  end
end

Account.new.state       # => "active"
Account.new.suspend     # => true
```

- An explicit `initial:`, static or dynamic, always wins over the schema
  default (and the "different default" warning is printed). A dynamic one is
  evaluated after the attributes given to `new` are assigned, so it can depend
  on them; a state given to `new` is kept.
- The default is read when a record is built, not when the class is loaded,
  so defining the machine before the table exists (e.g. while migrating) is
  fine.
- A default that names no defined state is ignored: the initial state stays
  `nil` and the "different default" warning is printed at class load.

### Scopes
Usage of the generated scopes (assuming default column `state`):

```ruby
Vehicle.with_state(:parked)                         # also plural #with_states
Vehicle.without_states(:first_gear, :second_gear)   # also singular #without_state
```

#### Transparent Scopes
State scopes will return all records when `nil` is passed, making them perfect for search filters:

```ruby
Vehicle.with_state(nil)                            # Returns all vehicles
Vehicle.with_state(params[:state])                 # Returns all vehicles if params[:state] is nil
Vehicle.where(color: 'red').with_state(nil)        # Returns all red vehicles (chainable)
```

## Rails Enum Integration

When your ActiveRecord model uses Rails enums and defines a state machine on the same attribute, this gem automatically detects the conflict and provides seamless integration. This prevents method name collisions between Rails enum methods and state machine methods.

### Auto-Detection and Conflict Resolution

```ruby
class Order < ApplicationRecord
  # Rails enum definition
  enum :status, { pending: 0, processing: 1, completed: 2, cancelled: 3 }
  
  # State machine on the same attribute
  state_machine :status do
    state :pending, :processing, :completed, :cancelled
    
    event :process do
      transition pending: :processing
    end
    
    event :complete do
      transition processing: :completed
    end
    
    event :cancel do
      transition [:pending, :processing] => :cancelled
    end
  end
end
```

When enum integration is detected, the gem automatically:
- Preserves original Rails enum methods (`pending?`, `processing?`, etc.)
- Generates prefixed state machine methods to avoid conflicts (`status_pending?`, `status_processing?`, etc.)
- Creates prefixed scope methods (`Order.status_pending`, `Order.status_processing`, etc.)

### Available Methods

**Original Rails enum methods (preserved):**
```ruby
order = Order.create(status: :pending)
order.pending?        # => true (Rails enum method)
order.processing?     # => false (Rails enum method)
order.processing!     # => writes the state directly; raises StateMachines::DirectStateAssignment with direct_assignment: :deny
order.process         # Fire the event instead

Order.pending         # Rails enum scope
Order.processing      # Rails enum scope
```

**Generated state machine methods (prefixed):**
```ruby
# Predicate methods
order.status_pending?     # => true (state machine method)
order.status_processing?  # => false (state machine method)
order.status_completed?   # => false (state machine method)

# Bang methods (for conflict resolution only)
# These are placeholders and raise runtime errors
order.status_processing!  # => raises RuntimeError

# Scope methods  
Order.status_pending      # State machine scope
Order.status_processing   # State machine scope
Order.not_status_pending  # Negative state machine scope
```

### Introspection API

The integration provides a comprehensive introspection API for advanced use cases:

```ruby
machine = Order.state_machine(:status)

# Check if enum integration is enabled
machine.enum_integrated?  # => true

# Get the Rails enum mapping
machine.enum_mapping     # => {"pending"=>0, "processing"=>1, "completed"=>2, "cancelled"=>3}

# Get original Rails enum methods that were preserved
machine.original_enum_methods
# => ["pending?", "processing?", "completed?", "cancelled?", "pending!", "processing!", ...]

# Get state machine methods that were generated
machine.state_machine_methods  
# => ["status_pending?", "status_processing?", "status_completed?", "status_cancelled?", ...]
```

## Integer-backed state attributes

Integer columns whose states don't declare explicit values are converted
transparently: application code reads state names while the database stores
integers (mapped by definition order).

```ruby
class Order < ApplicationRecord
  state_machine :status, initial: :pending do
    state :pending
    state :approved

    event :approve do
      transition pending: :approved
    end
  end
end

order = Order.create!
order.approve!
order.status # => "approved"
# The database stores 1.
```

Machines where every state declares an explicit integer value keep the classic
raw-integer behavior automatically: reads return the integer and `status_name`
returns the state name:

```ruby
class LegacyOrder < ApplicationRecord
  self.table_name = "orders"

  state_machine :status, initial: :pending do
    state :pending, value: 0
    state :approved, value: 1

    event :approve do
      transition pending: :approved
    end
  end
end

order = LegacyOrder.create!
order.approve!
order.status      # => 1
order.status_name # => :approved
# The database stores 1.
```

Applications that want no type conversion at all can disable it during boot,
before defining affected state machines:

```ruby
# config/initializers/state_machines.rb

StateMachines::Integrations::ActiveRecord.auto_convert_integer_state_attributes = false
```

With this setting disabled, integer-backed state attributes are left entirely
to ActiveRecord's normal integer handling.

### Requirements for Enum Integration

- The state machine attribute must match an existing Rails enum attribute
- Auto-detection is enabled by default when this condition is met

### Configuration Options

The enum integration supports several configuration options:

- `prefix` (default: true) - Adds a prefix to generated methods to avoid conflicts
- `suffix` (default: false) - Alternative naming strategy using suffixes instead of prefixes
- `scopes` (default: true) - Controls whether state machine scopes are generated

## State driven validations

As mentioned in `StateMachines::Machine#state`, you can define behaviors,
like validations, that only execute for certain states. One *important*
caveat here is that, due to a constraint in ActiveRecord's validation
framework, custom validators will not work as expected when defined to run
in multiple states. For example:

```ruby
class Vehicle < ApplicationRecord
  state_machine do
    state :first_gear, :second_gear do
      validate :speed_is_legal
    end
  end
end
```

In this case, the <tt>:speed_is_legal</tt> validation will only get run
for the <tt>:second_gear</tt> state.  To avoid this, you can define your
custom validation like so:

```ruby
class Vehicle < ApplicationRecord
  state_machine do
    state :first_gear, :second_gear do
      validate {|vehicle| vehicle.speed_is_legal}
    end
  end
end
```

## Transient state attributes

A machine can live on an attribute that is not a database column, either an
`attr_accessor` or an Attributes API `attribute` with no column behind it:

```ruby
class Order < ApplicationRecord
  attribute :stage, :string

  state_machine :stage, initial: ->(order) { order.paid_at ? :paid : :open } do
    state :open, :paid
  end
end
```

The initial state is applied to new records *and* to records loaded from the
database (loading skips `initialize`, so the integration fills the blank
attribute itself). That happens before `after_find`/`after_initialize`
callbacks run, so those see the initialized state and may fire events from it
(writing the state directly raises, as everywhere else). State-scoped validations run
as they do for column-backed machines, and the attribute's writer follows the
same [event-only rule](#state-changes-go-through-events) (there is no column,
so the raw-repair APIs do not apply). Machines on real columns are never
re-initialized on load: a `NULL` in the database stays `nil`.

## Why an event was refused

An event method still returns `false` when it is refused, and `errors` is filled
as before. The `<event>_refusal` reader from state_machines tells the reasons
apart (`nil` after a success):

| Reason           | When                                                                     |
|------------------|--------------------------------------------------------------------------|
| `:no_transition` | No transition for the event from the current state                       |
| `:guard`         | An `if:`/`unless:` rejected the transition                               |
| `:halted`        | A `before_transition` returned `false`, or an `around_transition` did not yield |
| `:action_failed` | `save` returned `false` (validations, a `before_save` that throws `:abort`) or `save!` raised |

```ruby
vehicle.shift_up             # => false
vehicle.shift_up_refusal     # => :action_failed
vehicle.errors.full_messages # => ["Seatbelt on can't be blank"]

vehicle.shift_up!            # => StateMachines::InvalidTransition, #reason => :action_failed

# Event attributes record the reason too, including when save! raises
vehicle.state_event = 'shift_up'
vehicle.save!                # => ActiveRecord::RecordInvalid
vehicle.shift_up_refusal     # => :action_failed
```

In parallel (`fire_events`) only the events that caused the refusal carry a
reason; a failed `save` is shared, so all of them read `:action_failed`.

When `save` fails because another machine's event attribute was refused inside
it, the fired event carries that reason, matching the bang message:

```ruby
vehicle.alarm_state_event = 'disable' # its before_transition halts
vehicle.ignite                        # => false
vehicle.ignite_refusal                # => :halted (not :action_failed)
```

`reload` forgets the reasons, and a `dup` / `clone` starts without any. The
reader reports the most recent attempt on the record, so code firing events on
one record from several threads should rely on the bang method's
`InvalidTransition#reason` instead.

## Contributing

1. Fork it ( https://github.com/state-machines/state_machines-activerecord/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
