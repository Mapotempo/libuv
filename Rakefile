require 'rubygems'
require 'bundler/setup'
require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'cucumber'
require 'cucumber/rake/task'
require 'yard'
require 'ffi'
require 'rake/clean'
require 'libuv/ext/tasks'

task :default => :test

RSpec::Core::RakeTask.new(:spec)
Cucumber::Rake::Task.new(:features)

YARD::Rake::YardocTask.new do |t|
    t.files   = ['lib/**/*.rb', '-', 'ext/README.md', 'README.md']
end

task :test => [:spec, :features]

desc "Compile libuv from submodule"
task :compile => ["ext/libuv.#{FFI::Platform::LIBSUFFIX}"]

CLOBBER.include("ext/libuv.#{FFI::Platform::LIBSUFFIX}")
