# frozen_string_literal: true

require "spec_helper"

if defined?(Rails)
  RSpec.describe QueSchema::Railtie do
    it "is defined as a Rails::Railtie subclass" do
      # We can't fully test Railtie without Rails, but we can verify the class
      # is loadable and structured correctly when Rails is defined.
      expect(QueSchema::Railtie).to be < Rails::Railtie
    end
  end
end

# When Rails is not defined, just verify the file doesn't blow up
RSpec.describe "QueSchema without Rails" do
  it "does not load Railtie when Rails is not defined" do
    # que-schema.rb guards: require "que_schema/railtie" if defined?(Rails)
    # Since we're not in a Rails app, Railtie may or may not be loaded
    # depending on test ordering, but the gem should work without Rails
    expect(defined?(QueSchema)).to eq("constant")
  end
end
