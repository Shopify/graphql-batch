require "bundler/gem_tasks"
require "rake/testtask"

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList['test/**/*_test.rb']
end

task :rubocop do
  require 'rubocop/rake_task'
  RuboCop::RakeTask.new
end

task(default: [:test, :rubocop])
