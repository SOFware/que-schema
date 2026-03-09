# frozen_string_literal: true

require "spec_helper"

RSpec.describe "QueSchema schema load" do
  let(:conn) { QueSchema::Spec.connection }

  after do
    QueSchema::Spec.clean!
  end

  it "que_define_schema(version: 7) creates the full Que schema" do
    c = conn
    schema_context = Object.new
    schema_context.extend(QueSchema::SchemaStatements)
    schema_context.define_singleton_method(:connection) { c }
    schema_context.que_define_schema(version: 7)

    # Tables
    expect(conn.table_exists?(:que_jobs)).to be true
    expect(conn.table_exists?(:que_values)).to be true
    expect(conn.table_exists?(:que_lockers)).to be true

    # Functions
    r = conn.execute(<<~SQL)
      SELECT proname FROM pg_proc WHERE proname IN ('que_validate_tags', 'que_job_notify', 'que_determine_job_state', 'que_state_notify')
    SQL
    names = r.map { |row| row["proname"] || row[:proname] }
    expect(names).to contain_exactly("que_validate_tags", "que_job_notify", "que_determine_job_state", "que_state_notify")

    # Triggers
    r = conn.execute("SELECT tgname FROM pg_trigger WHERE tgrelid = 'que_jobs'::regclass AND tgname IN ('que_job_notify', 'que_state_notify')")
    names = r.map { |row| row["tgname"] || row[:tgname] }
    expect(names).to contain_exactly("que_job_notify", "que_state_notify")
  end

  it "que_define_schema creates que_lockers as UNLOGGED" do
    c = conn
    schema_context = Object.new.extend(QueSchema::SchemaStatements)
    schema_context.define_singleton_method(:connection) { c }
    schema_context.que_define_schema(version: 7)

    r = conn.execute("SELECT relpersistence FROM pg_class WHERE relname = 'que_lockers'")
    expect(r.first["relpersistence"] || r.first[:relpersistence]).to eq("u")
  end
end
