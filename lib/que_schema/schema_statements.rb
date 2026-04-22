# frozen_string_literal: true

require "que"

module QueSchema
  # DSL methods for schema.rb: available in ActiveRecord::Schema and ActiveRecord::Migration
  # so that db:schema:load can execute que_define_schema.
  module SchemaStatements
    # Recreates the full Que schema for the given version by delegating to
    # Que.migrate!. This creates tables, functions, triggers, indexes, and
    # all other database objects that Que needs.
    def que_define_schema(version:)
      return unless postgresql?

      Que.connection_proc = proc { |&block| block.call(connection.raw_connection) }
      Que.migrate!(version: version.to_i)
      apply_que_scheduler_schema
    end

    def apply_que_scheduler_schema
      return unless defined?(Que::Scheduler::Migrations)

      Que::Scheduler::Migrations.migrate!(version: Que::Scheduler::Migrations::MAX_VERSION)
    end

    private

    def postgresql?
      return false unless respond_to?(:connection)

      conn = connection
      conn.respond_to?(:adapter_name) && conn.adapter_name.match?(/postgresql/i)
    end
  end
end
