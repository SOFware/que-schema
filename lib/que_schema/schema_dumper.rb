# frozen_string_literal: true

module QueSchema
  # Prepended into ActiveRecord::SchemaDumper to emit que_define_schema
  # and suppress Que-managed tables (Que.migrate! recreates them on load).
  module SchemaDumper
    private

    def tables(stream)
      # Emit que_define_schema before tables so Que objects
      # exist when later functions/triggers reference them.
      if postgresql? && (version = que_schema_version) && version > 0
        stream.puts "  # Que internal schema — emitted by que-schema gem"
        stream.puts "  que_define_schema(version: #{version})"
        stream.puts
      end

      super
    end

    # Suppress Que-managed tables — Que.migrate! recreates them during
    # schema load via que_define_schema.
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

    # Only objects created by Que.migrate! — other que_*
    # objects (e.g. que_scheduler_*) belong to separate gems
    # unless que-schema manages them too.
    QUE_MANAGED_TABLES = %w[
      que_jobs que_lockers que_values
    ].freeze

    QUE_MANAGED_FUNCTIONS = %w[
      que_validate_tags que_determine_job_state
      que_job_notify que_state_notify
    ].freeze

    QUE_MANAGED_TRIGGERS = %w[
      que_job_notify que_state_notify
    ].freeze

    QUE_SCHEDULER_TABLES = %w[
      que_scheduler_audit que_scheduler_audit_enqueued
    ].freeze

    QUE_SCHEDULER_FUNCTIONS = %w[
      que_scheduler_check_job_exists
      que_scheduler_prevent_job_deletion
    ].freeze

    QUE_SCHEDULER_TRIGGERS = %w[
      que_scheduler_prevent_job_deletion_trigger
    ].freeze

    def que_scheduler?
      defined?(Que::Scheduler::Migrations)
    end

    def que_table?(table_name)
      return true if QUE_MANAGED_TABLES.include?(table_name)
      return true if que_scheduler? && QUE_SCHEDULER_TABLES.include?(table_name)

      false
    end

    def que_function?(name)
      return true if QUE_MANAGED_FUNCTIONS.include?(name.to_s)
      return true if que_scheduler? && QUE_SCHEDULER_FUNCTIONS.include?(name.to_s)

      false
    end

    def que_trigger?(name)
      return true if QUE_MANAGED_TRIGGERS.include?(name.to_s)
      return true if que_scheduler? && QUE_SCHEDULER_TRIGGERS.include?(name.to_s)

      false
    end

    # Suppress foreign keys between Que-managed tables —
    # Que.migrate! / scheduler migrations recreate them.
    def foreign_keys(table, stream)
      return if postgresql? && que_table?(table.to_s)

      super
    end

    # Override Fx::SchemaDumper methods to filter out
    # Que-managed objects when Fx is present.
    def functions(stream)
      return super unless postgresql? && defined?(::Fx)

      dumpable = Fx.database.functions
        .reject { |f| que_function?(f.name) }
      dumpable.each { |f| stream.puts(f.to_schema) }
      stream.puts if dumpable.any?
    end

    def triggers(stream)
      return super unless postgresql? && defined?(::Fx)

      dumpable = Fx.database.triggers
        .reject { |t| que_trigger?(t.name) }
      stream.puts if dumpable.any?
      dumpable.each { |t| stream.puts(t.to_schema) }
    end
  end
end
