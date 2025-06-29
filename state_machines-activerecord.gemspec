# frozen_string_literal: true

require_relative 'lib/state_machines/integrations/active_record/version'

Gem::Specification.new do |spec|
  spec.name          = 'state_machines-activerecord'
  spec.version       = StateMachines::Integrations::ActiveRecord::VERSION
  spec.authors       = ['Abdelkader Boudih', 'Aaron Pfeifer']
  spec.email         = %w[terminale@gmail.com aaron@pluginaweek.org]
  spec.summary       = 'State machines Active Record Integration'
  spec.description   = 'Adds support for creating state machines for attributes on ActiveRecord'
  spec.homepage      = 'https://github.com/state-machines/state_machines-activerecord/'
  spec.license       = 'MIT'

  spec.files         = Dir['{lib}/**/*', 'LICENSE.txt', 'README.md']
  spec.required_ruby_version = '>= 3.1'
  spec.require_paths = ['lib']

  spec.add_dependency 'activerecord', '>= 7.1'
  spec.add_dependency 'state_machines-activemodel', '>= 0.10.0'
  spec.add_development_dependency 'appraisal', '>= 1'
  spec.add_development_dependency 'minitest', '>= 5.4.0'
  spec.add_development_dependency 'minitest-reporters'
  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'sqlite3', '~> 1.3'
  spec.metadata['rubygems_mfa_required'] = 'true'
end
