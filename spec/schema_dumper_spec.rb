# frozen_string_literal: true

require "spec_helper"
require "stringio"

RSpec.describe QueSchema::SchemaDumper do
  let(:connection) { double("connection") }

  let(:dumper_class) do
    mod = described_class
    Class.new do
      prepend mod

      attr_accessor :connection

      def initialize(connection)
        @connection = connection
      end

      def tables(stream)
        stream.puts "  # original tables output"
      end

      def table(table_name, stream)
        stream.puts "  create_table \"#{table_name}\", force: :cascade do |t|"
        stream.puts "  end"
      end

      private :tables, :table
    end
  end

  let(:dumper) { dumper_class.new(connection) }

  def stub_postgresql!
    allow(connection).to receive(:adapter_name).and_return("PostgreSQL")
    allow(connection).to receive(:respond_to?).with(:adapter_name).and_return(true)
  end

  describe "#tables" do
    context "when PostgreSQL with que_jobs" do
      before do
        stub_postgresql!
        allow(connection).to receive(:table_exists?).with("que_jobs").and_return(true)
        allow(connection).to receive(:execute).and_return([{"comment" => "7"}])
      end

      it "emits que_define_schema after tables" do
        stream = StringIO.new
        dumper.send(:tables, stream)
        output = stream.string

        expect(output).to include("que_define_schema(version: 7)")
        expect(output).to include("# original tables output")
        expect(output.index("que_define_schema")).to be > output.index("original tables")
      end
    end

    context "when PostgreSQL without que_jobs" do
      before do
        stub_postgresql!
        allow(connection).to receive(:table_exists?).with("que_jobs").and_return(false)
      end

      it "does not emit que_define_schema" do
        stream = StringIO.new
        dumper.send(:tables, stream)
        expect(stream.string).not_to include("que_define_schema")
      end
    end

    context "when not PostgreSQL" do
      before do
        allow(connection).to receive(:adapter_name).and_return("SQLite")
        allow(connection).to receive(:respond_to?).with(:adapter_name).and_return(true)
      end

      it "does not emit que_define_schema" do
        stream = StringIO.new
        dumper.send(:tables, stream)
        expect(stream.string).not_to include("que_define_schema")
      end
    end

    context "when comment is nil" do
      before do
        stub_postgresql!
        allow(connection).to receive(:table_exists?).with("que_jobs").and_return(true)
        allow(connection).to receive(:execute).and_return([{"comment" => nil}])
      end

      it "does not emit que_define_schema when version is 0" do
        stream = StringIO.new
        dumper.send(:tables, stream)
        expect(stream.string).not_to include("que_define_schema")
      end
    end
  end

  describe "#table" do
    context "when PostgreSQL" do
      before { stub_postgresql! }

      it "suppresses que_* tables" do
        stream = StringIO.new
        dumper.send(:table, "que_jobs", stream)
        expect(stream.string).to be_empty
      end

      it "suppresses que_lockers" do
        stream = StringIO.new
        dumper.send(:table, "que_lockers", stream)
        expect(stream.string).to be_empty
      end

      it "suppresses que_values" do
        stream = StringIO.new
        dumper.send(:table, "que_values", stream)
        expect(stream.string).to be_empty
      end

      it "suppresses any future que_* table" do
        stream = StringIO.new
        dumper.send(:table, "que_something_new", stream)
        expect(stream.string).to be_empty
      end

      it "does not suppress non-que tables" do
        stream = StringIO.new
        dumper.send(:table, "users", stream)
        expect(stream.string).to include('create_table "users"')
      end
    end

    context "when not PostgreSQL" do
      before do
        allow(connection).to receive(:adapter_name).and_return("SQLite")
        allow(connection).to receive(:respond_to?).with(:adapter_name).and_return(true)
      end

      it "does not suppress que_* tables" do
        stream = StringIO.new
        dumper.send(:table, "que_jobs", stream)
        expect(stream.string).to include('create_table "que_jobs"')
      end
    end
  end

  describe "#que_table? (private)" do
    it "returns true for que_ prefixed tables" do
      expect(dumper.send(:que_table?, "que_jobs")).to be true
      expect(dumper.send(:que_table?, "que_lockers")).to be true
      expect(dumper.send(:que_table?, "que_values")).to be true
      expect(dumper.send(:que_table?, "que_new_future_table")).to be true
    end

    it "returns false for non-que tables" do
      expect(dumper.send(:que_table?, "users")).to be false
      expect(dumper.send(:que_table?, "queue_items")).to be false
    end
  end

  describe "#que_schema_version (private)" do
    it "returns the version from the table comment" do
      allow(connection).to receive(:table_exists?).with("que_jobs").and_return(true)
      allow(connection).to receive(:execute).and_return([{"comment" => "7"}])
      expect(dumper.send(:que_schema_version)).to eq(7)
    end

    it "returns nil when que_jobs does not exist" do
      allow(connection).to receive(:table_exists?).with("que_jobs").and_return(false)
      expect(dumper.send(:que_schema_version)).to be_nil
    end

    it "returns 0 when comment is nil" do
      allow(connection).to receive(:table_exists?).with("que_jobs").and_return(true)
      allow(connection).to receive(:execute).and_return([{"comment" => nil}])
      expect(dumper.send(:que_schema_version)).to eq(0)
    end

    it "returns 0 when no rows returned" do
      allow(connection).to receive(:table_exists?).with("que_jobs").and_return(true)
      allow(connection).to receive(:execute).and_return([])
      expect(dumper.send(:que_schema_version)).to eq(0)
    end

    it "handles symbol key for comment" do
      allow(connection).to receive(:table_exists?).with("que_jobs").and_return(true)
      allow(connection).to receive(:execute).and_return([{comment: "7"}])
      expect(dumper.send(:que_schema_version)).to eq(7)
    end
  end

  describe "#postgresql? (private)" do
    it "returns true for PostgreSQL" do
      allow(connection).to receive(:respond_to?).with(:adapter_name).and_return(true)
      allow(connection).to receive(:adapter_name).and_return("PostgreSQL")
      expect(dumper.send(:postgresql?)).to be true
    end

    it "returns false for non-PostgreSQL" do
      allow(connection).to receive(:respond_to?).with(:adapter_name).and_return(true)
      allow(connection).to receive(:adapter_name).and_return("SQLite")
      expect(dumper.send(:postgresql?)).to be false
    end

    it "returns false when adapter_name is not available" do
      allow(connection).to receive(:respond_to?).with(:adapter_name).and_return(false)
      expect(dumper.send(:postgresql?)).to be false
    end
  end
end
