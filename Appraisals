appraise "active_record_5.1" do
  gem "sqlite3", platforms: [:mri, :rbx]
  gem "activerecord-jdbcsqlite3-adapter", platform: [:jruby, :truffleruby]
  gem "activerecord", '~> 5.1.1'
end

appraise "active_record_5.2" do
  gem "sqlite3", platforms: [:mri, :rbx]
  gem "activerecord-jdbcsqlite3-adapter", platform: [:jruby, :truffleruby]
  gem "activerecord", '~> 5.2.4'
end

appraise 'active_record_6.0' do
  gem "sqlite3", platforms: [:mri, :rbx]
  gem "activerecord-jdbcsqlite3-adapter", platform: [:jruby, :truffleruby]
  gem "activerecord", '~> 6.0.3'
end

appraise 'active_record_6.1' do
  gem "sqlite3", platforms: [:mri, :rbx]
  gem "activerecord-jdbcsqlite3-adapter", platform: [:jruby, :truffleruby]
  gem "activerecord", '~> 6.1.3'
end

appraise "active_record_edge" do
  gem "sqlite3", platforms: [:mri, :rbx]
  gem "activerecord-jdbcsqlite3-adapter", platform: [:jruby, :truffleruby]
  gem "activerecord", github: 'rails/rails',  branch: 'main'
  gem "activemodel", github: 'rails/rails', branch: 'main'
end
