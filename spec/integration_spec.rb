# frozen_string_literal: true

require "spec_helper"
require "stringio"

RSpec.describe "QueSchema integration (round-trip)" do
  let(:conn) { QueSchema::Spec.connection }
  let(:pool) { ActiveRecord::Base.connection_pool }

  after do
    QueSchema::Spec.clean!
  end

  it "full round-trip: create schema -> dump -> drop -> load -> verify" do
    # Create schema via que_define_schema (which delegates to Que.migrate!)
    c = conn
    schema_context = Object.new.extend(QueSchema::SchemaStatements)
    schema_context.define_singleton_method(:connection) { c }
    schema_context.que_define_schema(version: 7)

    # Dump schema
    stream = StringIO.new
    ActiveRecord::SchemaDumper.dump(pool, stream)
    schema_rb = stream.string

    expect(schema_rb).to include("que_define_schema(version: 7)")
    expect(schema_rb).not_to match(/create_table "que_jobs"/)
    expect(schema_rb).not_to match(/create_table "que_lockers"/)
    expect(schema_rb).not_to match(/create_table "que_values"/)

    # Drop everything
    QueSchema::Spec.clean!
    expect(conn.table_exists?(:que_jobs)).to be false

    # Load schema (eval the dumped schema)
    eval(schema_rb) # rubocop:disable Security/Eval

    # Verify tables were recreated by Que.migrate!
    expect(conn.table_exists?(:que_jobs)).to be true
    expect(conn.table_exists?(:que_values)).to be true
    expect(conn.table_exists?(:que_lockers)).to be true

    # Verify functions were recreated
    r = conn.execute(<<~SQL)
      SELECT proname FROM pg_proc
      WHERE proname IN ('que_validate_tags', 'que_job_notify', 'que_determine_job_state', 'que_state_notify')
    SQL
    names = r.map { |row| row["proname"] || row[:proname] }
    expect(names).to contain_exactly("que_validate_tags", "que_job_notify", "que_determine_job_state", "que_state_notify")

    # Verify triggers were recreated
    r = conn.execute(<<~SQL)
      SELECT tgname FROM pg_trigger
      WHERE tgrelid = 'que_jobs'::regclass
      AND tgname IN ('que_job_notify', 'que_state_notify')
    SQL
    trigger_names = r.map { |row| row["tgname"] || row[:tgname] }
    expect(trigger_names).to contain_exactly("que_job_notify", "que_state_notify")

    # Verify que_lockers is UNLOGGED
    r = conn.execute("SELECT relpersistence FROM pg_class WHERE relname = 'que_lockers'")
    expect(r.first["relpersistence"] || r.first[:relpersistence]).to eq("u")

    # Verify table comment (schema version)
    r = conn.execute(<<~SQL)
      SELECT obj_description(c.oid, 'pg_class') AS comment
      FROM pg_class c
      WHERE c.relname = 'que_jobs'
    SQL
    expect(r.first["comment"] || r.first[:comment]).to eq("7")

    # Verify a job can be inserted
    conn.execute("INSERT INTO que_jobs (queue, priority, job_class, args, data, job_schema_version) VALUES ('default', 100, 'TestJob', '[]', '{}', 7)")
    count = conn.execute("SELECT count(*) AS cnt FROM que_jobs")
    expect((count.first["cnt"] || count.first[:cnt]).to_i).to eq(1)
  end
end
