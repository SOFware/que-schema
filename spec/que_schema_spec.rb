# frozen_string_literal: true

require "spec_helper"

RSpec.describe QueSchema do
  it "has a version number" do
    expect(QueSchema::VERSION).to be_a(String)
    expect(QueSchema::VERSION).not_to be_empty
  end

  it "defines SchemaStatements module" do
    expect(QueSchema::SchemaStatements).to be_a(Module)
  end

  it "defines SchemaDumper module" do
    expect(QueSchema::SchemaDumper).to be_a(Module)
  end

  it "defines MigrationHelpers module" do
    expect(QueSchema::MigrationHelpers).to be_a(Module)
  end

  it "includes SchemaStatements in ActiveRecord::Migration" do
    expect(ActiveRecord::Migration.ancestors).to include(QueSchema::SchemaStatements)
  end

  it "includes MigrationHelpers in ActiveRecord::Migration" do
    expect(ActiveRecord::Migration.ancestors).to include(QueSchema::MigrationHelpers)
  end

  it "includes SchemaStatements in ActiveRecord::Schema" do
    expect(ActiveRecord::Schema.ancestors).to include(QueSchema::SchemaStatements)
  end

  it "prepends SchemaDumper into ActiveRecord::SchemaDumper" do
    expect(ActiveRecord::SchemaDumper.ancestors).to include(QueSchema::SchemaDumper)
  end
end
