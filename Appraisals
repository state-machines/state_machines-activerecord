# frozen_string_literal: true

appraise 'active_record_7.2' do
  gem 'sqlite3', platforms: %i[mri rbx]
  gem 'activerecord-jdbcsqlite3-adapter', platform: %i[jruby truffleruby]
  gem 'activerecord', '~> 7.2.0'
end

appraise 'active_record_8.0' do
  gem 'sqlite3', platforms: %i[mri rbx]
  gem 'activerecord-jdbcsqlite3-adapter', platform: %i[jruby truffleruby]
  gem 'activerecord', '~> 8.0.0'
end

appraise 'active_record_edge' do
  gem 'sqlite3', platforms: :mri
  gem 'activerecord-jdbcsqlite3-adapter', platform: %i[jruby truffleruby]
  gem 'activerecord', github: 'rails/rails'
  gem 'activemodel', github: 'rails/rails'
end
