appraise "active_record_4.1" do
 gem "sqlite3", platforms: [:mri, :rbx]
 gem "activerecord-jdbcsqlite3-adapter", platform: :jruby
 gem "activerecord", github: 'rails/rails',  branch: '4-1-stable'
end

appraise "active_record_4.2" do
  gem "sqlite3", platforms: [:mri, :rbx]
  gem "activerecord-jdbcsqlite3-adapter", platform: :jruby
  gem "activerecord", github: 'rails/rails',  branch: '4-2-stable'
end

appraise "active_record_edge" do
  gem "sqlite3", platforms: [:mri, :rbx]
  gem "activerecord-jdbcsqlite3-adapter", platform: :jruby
  gem "activerecord", github: 'rails/rails',  branch: 'master'
  gem "method_source"  # appears to be a missing dependency of activerecord
  gem "arel", github: 'rails/arel', branch: 'master'
  gem "activemodel", github: 'rails/rails', branch: 'master'
  gem "state_machines-activemodel", '0.4.0.pre'
end
