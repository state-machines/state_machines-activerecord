# Only appraising legacy Rails that are no longer supported by the standard gem.
appraise "active_record_4.0" do
  gem "sqlite3", platforms: [:mri, :rbx]
  gem "activerecord-jdbcsqlite3-adapter", platform: :jruby
  gem "activerecord", "~> 4.0"
end
