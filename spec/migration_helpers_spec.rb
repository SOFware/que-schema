# frozen_string_literal: true

require "spec_helper"

RSpec.describe QueSchema::MigrationHelpers do
  let(:test_class) do
    Class.new do
      include QueSchema::SchemaStatements
      include QueSchema::MigrationHelpers

      attr_accessor :connection
    end
  end

  let(:connection) { QueSchema::Spec.connection }
  let(:instance) { test_class.new.tap { |i| i.connection = connection } }

  after do
    QueSchema::Spec.clean!
  end

  describe "#create_que_schema" do
    it "delegates to que_define_schema" do
      expect(instance).to receive(:que_define_schema).with(version: 7)
      instance.create_que_schema(version: 7)
    end

    it "creates the full Que schema" do
      instance.create_que_schema(version: 7)
      expect(connection.table_exists?(:que_jobs)).to be true
    end
  end

  describe "#drop_que_schema" do
    it "removes all Que tables, functions, and triggers" do
      instance.create_que_schema(version: 7)
      expect(connection.table_exists?(:que_jobs)).to be true

      instance.drop_que_schema
      expect(connection.table_exists?(:que_jobs)).to be false
      expect(connection.table_exists?(:que_values)).to be false
      expect(connection.table_exists?(:que_lockers)).to be false
    end

    context "when not PostgreSQL" do
      let(:connection) { double("connection", adapter_name: "SQLite") }

      it "does nothing" do
        expect(connection).not_to receive(:execute)
        instance.drop_que_schema
      end
    end
  end
end
