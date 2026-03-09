# frozen_string_literal: true

require_relative "lib/que_schema/version"

Gem::Specification.new do |spec|
  spec.name = "que-schema"
  spec.version = QueSchema::VERSION
  spec.authors = ["Jim Gay"]
  spec.email = ["jim@saturnflyer.com"]

  spec.summary = "Enables schema.rb compatibility for the que job queue gem"
  spec.description = "Patches Rails' ActiveRecord schema dumper so applications using que-rb/que can use schema.rb instead of structure.sql. Round-trips Que's PostgreSQL functions, triggers, and options through the Ruby schema format."
  spec.homepage = "https://github.com/SOFware/que-schema"
  spec.required_ruby_version = ">= 2.7"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage

  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ .gitignore])
    end
  end
  spec.require_paths = ["lib"]

  spec.add_dependency "activerecord", ">= 6.0"
  spec.add_dependency "que"
  spec.add_dependency "railties", ">= 6.0"
end
