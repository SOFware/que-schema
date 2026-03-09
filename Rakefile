# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"
require "reissue/gem"

RSpec::Core::RakeTask.new(:spec)

Reissue::Task.create :reissue do |task|
  task.version_file = "lib/que_schema/version.rb"
  task.fragment = :git
  task.push_finalize = :branch
end

task default: :spec
