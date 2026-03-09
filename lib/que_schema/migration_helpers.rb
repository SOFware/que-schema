# frozen_string_literal: true

require "que"

module QueSchema
  # Convenience methods for migrations when setting up Que via ActiveRecord.
  module MigrationHelpers
    # Creates the Que schema for the given version.
    # Delegates to Que.migrate! which handles everything.
    def create_que_schema(version:)
      que_define_schema(version: version)
    end

    # Drops the entire Que schema by migrating down to version 0.
    # Removes all Que tables, functions, and triggers.
    def drop_que_schema
      return unless connection.adapter_name.match?(/postgresql/i)

      Que.connection_proc = proc { |&block| block.call(connection.raw_connection) }
      Que.migrate!(version: 0)
    end
  end
end
