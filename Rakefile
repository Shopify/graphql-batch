require "bundler/gem_tasks"
require "rake/testtask"

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList['test/**/*_test.rb']
end

task(default: :test)

if Gem::Version.new(RUBY_VERSION) >= Gem::Version.new('2.4.0')
  task :rubocop do
    require 'rubocop/rake_task'
    RuboCop::RakeTask.new
  end

  task(default: :rubocop)
end
