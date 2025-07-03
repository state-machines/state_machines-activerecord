[![Build Status](https://github.com/state-machines/state_machines-activerecord/actions/workflows/ruby.yml/badge.svg)](https://github.com/state-machines/state_machines-activerecord/actions/workflows/ruby.yml)

# StateMachines Active Record Integration

The Active Record 7.2+ integration adds support for database transactions, automatically
saving the record, named scopes, validation errors.

## Requirements

- Ruby 3.2+
- Rails 7.2+

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
order.processing!     # Sets status to :processing (Rails enum method)

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


### Requirements for Enum Integration

- The state machine attribute must match an existing Rails enum attribute
- Auto-detection is enabled by default when this condition is met

### Configuration Options

The enum integration supports several configuration options:

- `prefix` (default: true) - Adds a prefix to generated methods to avoid conflicts
- `suffix` (default: false) - Alternative naming strategy using suffixes instead of prefixes
- `validate` (default: true) - Controls whether enum validation is integrated with state machine validations
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

## Contributing

1. Fork it ( https://github.com/state-machines/state_machines-activerecord/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
