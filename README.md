[![Build Status](https://travis-ci.org/state-machines/state_machines-activerecord.svg?branch=master)](https://travis-ci.org/state-machines/state_machines-activerecord)
[![Code Climate](https://codeclimate.com/github/state-machines/state_machines-activerecord.png)](https://codeclimate.com/github/state-machines/state_machines-activerecord)

# StateMachines Active Record Integration

The Active Record integration adds support for database transactions, automatically
saving the record, named scopes, validation errors.

## Installation

Add this line to your application's Gemfile:

    gem 'state_machines-activerecord'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install state_machines-activerecord

## Usage

```ruby
class Vehicle < ActiveRecord::Base
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
      validates_presence_of :seatbelt_on
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


Dependencies

Active Record 4.1+

## Contributing

1. Fork it ( https://github.com/state-machines/state_machines-activerecord/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
