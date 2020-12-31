# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'state_machines/integrations/active_record/version'

Gem::Specification.new do |spec|
  spec.name          = 'state_machines-activerecord'
  spec.version       = StateMachines::Integrations::ActiveRecord::VERSION
  spec.authors       = ['Abdelkader Boudih', 'Aaron Pfeifer']
  spec.email         = %w(terminale@gmail.com aaron@pluginaweek.org)
  spec.summary       = %q(State machines Active Record Integration)
  spec.description   = %q(Adds support for creating state machines for attributes on ActiveRecord)
  spec.homepage      = 'https://github.com/state-machines/state_machines-activerecord/'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0")
  spec.test_files    = spec.files.grep(/^test\//)
  spec.required_ruby_version     = '>= 2.2.2'
  spec.require_paths = ['lib']

  spec.add_dependency 'state_machines-activemodel', '>= 0.8.0'
  spec.add_dependency 'activerecord' , '>= 5.1'
  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'sqlite3', '~> 1.3'
  spec.add_development_dependency 'appraisal', '>= 1'
  spec.add_development_dependency 'minitest' , '>= 5.4.0'
  spec.add_development_dependency 'minitest-reporters'
end
