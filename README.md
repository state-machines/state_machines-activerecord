[![Build Status](https://github.com/state-machines/state_machines-activerecord/actions/workflows/ruby.yml/badge.svg)](https://github.com/state-machines/state_machines-activerecord/actions/workflows/ruby.yml)

# StateMachines Active Record Integration

The Active Record 5.1+ integration adds support for database transactions, automatically
saving the record, named scopes, validation errors.

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

### State driven validations

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
