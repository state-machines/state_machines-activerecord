# frozen_string_literal: true

appraise 'active_record_8.0' do
  gem 'state_machines', '>= 0.100.4'
  gem 'state_machines-activemodel', '>= 0.200.0'
  gem 'sqlite3', platforms: :mri
  gem 'activerecord-jdbcsqlite3-adapter', platform: %i[jruby truffleruby]
  gem 'activerecord', '~> 8.0.0'
end

appraise 'active_record_8.1' do
  gem 'state_machines', '>= 0.100.4'
  gem 'state_machines-activemodel', '>= 0.200.0'
  gem 'sqlite3', platforms: :mri
  gem 'activerecord-jdbcsqlite3-adapter', platform: %i[jruby truffleruby]
  gem 'activerecord', '~> 8.1.0'
end

appraise 'active_record_edge' do
  gem 'state_machines', '>= 0.100.4'
  gem 'state_machines-activemodel', '>= 0.200.0'
  gem 'sqlite3', platforms: :mri
  gem 'activerecord-jdbcsqlite3-adapter', platform: %i[jruby truffleruby]
  gem 'activerecord', github: 'rails/rails', branch: 'main'
  gem 'activemodel', github: 'rails/rails', branch: 'main'
end
