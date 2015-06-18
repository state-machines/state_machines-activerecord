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
  spec.homepage      = 'https://github.com/seuros/state_machines-activerecord'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0")
  spec.test_files    = spec.files.grep(/^test\//)
  spec.require_paths = ['lib']

  spec.add_dependency 'state_machines-activemodel', '>= 0.3.0'
  spec.add_dependency 'activerecord' , '~> 4.1'
  spec.add_development_dependency 'rake', '~> 10.3'
  spec.add_development_dependency 'sqlite3', '~> 1.3'
  spec.add_development_dependency 'appraisal', '>= 1'
  spec.add_development_dependency 'minitest' , '>= 5.4.0'
  spec.add_development_dependency 'minitest-reporters'
end
