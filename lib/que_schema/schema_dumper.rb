# frozen_string_literal: true

module QueSchema
  # Prepended into ActiveRecord::SchemaDumper to emit que_define_schema
  # and suppress Que-managed tables (Que.migrate! recreates them on load).
  module SchemaDumper
    private

    def tables(stream)
      super

      if postgresql? && (version = que_schema_version) && version > 0
        stream.puts "  # Que internal schema — emitted by que-schema gem"
        stream.puts "  que_define_schema(version: #{version})"
        stream.puts
      end
    end

    # Suppress all que_* tables — Que.migrate! creates them during schema load.
    def table(table_name, stream)
      return if postgresql? && que_table?(table_name)

      super
    end

    def que_schema_version
      return nil unless @connection.table_exists?("que_jobs")

      result = @connection.execute(<<~SQL)
        SELECT obj_description(c.oid, 'pg_class') AS comment
        FROM pg_class c
        WHERE c.relname = 'que_jobs'
        AND c.relnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public')
      SQL
      raw = result.first&.[]("comment") || result.first&.[](:comment)
      raw.to_s.strip.to_i
    end

    def postgresql?
      @connection.respond_to?(:adapter_name) && @connection.adapter_name.match?(/postgresql/i)
    end

    def que_table?(table_name)
      table_name.start_with?("que_")
    end
  end
end
