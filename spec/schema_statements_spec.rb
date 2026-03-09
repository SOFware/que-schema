# frozen_string_literal: true

require "spec_helper"

RSpec.describe QueSchema::SchemaStatements do
  let(:test_class) do
    Class.new do
      include QueSchema::SchemaStatements

      attr_accessor :connection
    end
  end

  let(:connection) { QueSchema::Spec.connection }
  let(:instance) { test_class.new.tap { |i| i.connection = connection } }

  after do
    QueSchema::Spec.clean!
  end

  describe "#que_define_schema" do
    context "when not PostgreSQL" do
      let(:connection) { double("connection", adapter_name: "SQLite") }

      it "returns nil without executing SQL" do
        expect(connection).not_to receive(:execute)
        result = instance.que_define_schema(version: 7)
        expect(result).to be_nil
      end
    end

    context "when PostgreSQL" do
      it "creates all Que tables, functions, and triggers for version 7" do
        instance.que_define_schema(version: 7)

        expect(connection.table_exists?(:que_jobs)).to be true
        expect(connection.table_exists?(:que_values)).to be true
        expect(connection.table_exists?(:que_lockers)).to be true

        r = connection.execute("SELECT proname FROM pg_proc WHERE proname IN ('que_validate_tags', 'que_job_notify', 'que_determine_job_state', 'que_state_notify')")
        names = r.map { |row| row["proname"] || row[:proname] }
        expect(names).to contain_exactly("que_validate_tags", "que_job_notify", "que_determine_job_state", "que_state_notify")
      end

      it "creates que_lockers as UNLOGGED" do
        instance.que_define_schema(version: 7)

        r = connection.execute("SELECT relpersistence FROM pg_class WHERE relname = 'que_lockers'")
        expect(r.first["relpersistence"] || r.first[:relpersistence]).to eq("u")
      end

      it "creates triggers on que_jobs" do
        instance.que_define_schema(version: 7)

        r = connection.execute("SELECT tgname FROM pg_trigger WHERE tgrelid = 'que_jobs'::regclass AND tgname IN ('que_job_notify', 'que_state_notify')")
        names = r.map { |row| row["tgname"] || row[:tgname] }
        expect(names).to contain_exactly("que_job_notify", "que_state_notify")
      end

      it "is idempotent" do
        instance.que_define_schema(version: 7)
        expect { instance.que_define_schema(version: 7) }.not_to raise_error
      end
    end
  end

  describe "#postgresql? (private)" do
    it "returns false when no connection method exists" do
      obj = Object.new
      obj.extend(QueSchema::SchemaStatements)
      expect(obj.send(:postgresql?)).to be false
    end

    it "returns false for non-PostgreSQL adapters" do
      fake_conn = double("connection", adapter_name: "Mysql2")
      allow(fake_conn).to receive(:respond_to?).with(:adapter_name).and_return(true)
      inst = test_class.new.tap { |i| i.connection = fake_conn }
      expect(inst.send(:postgresql?)).to be false
    end

    it "returns true for PostgreSQL adapter" do
      expect(instance.send(:postgresql?)).to be true
    end
  end
end
