# frozen_string_literal: true

require "simplecov"
require "simplecov_json_formatter"
SimpleCov.formatters = SimpleCov::Formatter::MultiFormatter.new([
  SimpleCov::Formatter::HTMLFormatter,
  SimpleCov::Formatter::JSONFormatter
])
SimpleCov.start do
  add_filter %r{spec/}
  add_filter %r{vendor/}
  minimum_coverage 90
end

require "active_record"
require "que-schema"
require "support/database"

# Apply patches when running without Rails (Railtie only runs when Rails boots)
ActiveRecord::Migration.include(QueSchema::SchemaStatements)
ActiveRecord::Migration.include(QueSchema::MigrationHelpers)
ActiveRecord::Schema.include(QueSchema::SchemaStatements)
ActiveRecord::SchemaDumper.prepend(QueSchema::SchemaDumper)

# Establish database connection for all specs
QueSchema::Spec.establish_connection

# Suppress migration output during tests
ActiveRecord::Migration.verbose = false

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end
  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end
  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.filter_run_when_matching :focus
end
