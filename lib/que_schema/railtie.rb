# frozen_string_literal: true

module QueSchema
  class Railtie < ::Rails::Railtie
    config.before_initialize do
      ActiveSupport.on_load(:active_record) do
        ActiveRecord::Migration.include(QueSchema::SchemaStatements)
        ActiveRecord::Migration.include(QueSchema::MigrationHelpers)
        ActiveRecord::Schema.include(QueSchema::SchemaStatements)
      end
    end

    # Prepend SchemaDumper after initialization so it sits
    # above Fx/Scenic in the ancestor chain and can filter
    # out Que-managed functions and triggers.
    config.after_initialize do
      ActiveRecord::SchemaDumper.prepend(QueSchema::SchemaDumper)
    end
  end
end
