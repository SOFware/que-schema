# frozen_string_literal: true

require "active_record"
require "que"

module QueSchema
  module Spec
    DATABASE_NAME = "que_schema_test"
    DATABASE_URL = ENV["DATABASE_URL"] || "postgresql://localhost/#{DATABASE_NAME}"

    def self.establish_connection
      return if @connected

      begin
        ActiveRecord::Base.establish_connection(DATABASE_URL)
        ActiveRecord::Base.connection.execute("SELECT 1")
      rescue ActiveRecord::NoDatabaseError
        create_database
        ActiveRecord::Base.establish_connection(DATABASE_URL)
      end

      @connected = true
    end

    def self.create_database
      base_url = DATABASE_URL.sub(%r{/[^/]+\z}, "/postgres")
      ActiveRecord::Base.establish_connection(base_url)
      ActiveRecord::Base.connection.create_database(DATABASE_NAME)
    end

    def self.connection
      establish_connection
      ActiveRecord::Base.connection
    end

    def self.clean!
      conn = connection

      # Delegate to Que.migrate! which drops everything in the correct order,
      # respecting dependencies between constraints, functions, and tables.
      Que.connection_proc = proc { |&block| block.call(conn.raw_connection) }
      Que.migrate!(version: 0)
    rescue
      # If Que.migrate! fails (e.g. tables don't exist), dynamically discover
      # and drop all que_* objects so we don't hardcode Que's internal names.
      conn.execute(<<~SQL).each { |row| conn.execute("DROP TABLE IF EXISTS #{conn.quote_table_name(row["tablename"])} CASCADE") }
        SELECT tablename FROM pg_tables WHERE schemaname = 'public' AND tablename LIKE 'que_%'
      SQL
      conn.execute(<<~SQL).each { |row| conn.execute("DROP FUNCTION IF EXISTS #{row["oid"]}::regprocedure CASCADE") }
        SELECT oid FROM pg_proc WHERE proname LIKE 'que_%' AND pronamespace = 'public'::regnamespace
      SQL
    end
  end
end
