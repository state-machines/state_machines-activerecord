# frozen_string_literal: true

source 'https://rubygems.org'
gemspec

# Use state_machines from cereals branch for fiber deadlock fix
gem 'state_machines', github: 'state-machines/state_machines', branch: 'cereals'

platforms :mri do
  gem 'debug'
end
