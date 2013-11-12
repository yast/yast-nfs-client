#! /usr/bin/env rspec

ENV["Y2DIR"] = File.expand_path("../../src", __FILE__)

require "yast"

Yast.import "NfsOptions"

describe "#validate" do
  it "returns empty string on correct options" do
    [
      "defaults",
      "nolock,bg",
      "nolock,nobg",
      "nolock,rsize=8192",
      "defaults,ro,noatime,nodiratime,users,exec"
    ].each do |options|
      returned = Yast::NfsOptions.validate(options)
      expect(returned).to be_empty, "options '#{options}' returned '#{returned}'"
    end
  end

  it "returns 'Empty option strings are not allowed' error message on empty options" do
    returned = Yast::NfsOptions.validate("")
    expect(returned).to start_with("Empty option strings are not allowed"), "options '' returned '#{returned}'"
  end

  it "returns 'Empty value' error message on options that expect key=value and the value is empty" do
    [
      "noatime,port=",
      "mountvers=",
      "mountvers,=port=23",
      "nolock,rsize=",
    ].each do |options|
      returned = Yast::NfsOptions.validate(options)
      expect(returned).to start_with("Empty value"), "options '#{options}' returned '#{returned}'"
    end
  end

  it "returns 'Invalid option' error message on options that expect key=value and the value contains '='" do
    [
      "noatime,port=dort=fort",
      "mountvers=port=23",
      "nolock,retrans=trans=trans",
    ].each do |options|
      returned = Yast::NfsOptions.validate(options)
      expect(returned).to start_with("Invalid option"), "options '#{options}' returned '#{returned}'"
    end
  end

  it "returns 'Unknown option' error message on options that are unknown" do
    [
      "noatime,unknownparam",
      "mountvers2",
      "nolock, bg",
      "nolock,unknownoption",
      "nolock,unknownassignment=true",
      "nolock,intr=bogus",
      "nolock,two=equal=signs",
    ].each do |options|
      returned = Yast::NfsOptions.validate(options)
      expect(returned).to start_with("Unknown option"), "options '#{options}' returned '#{returned}'"
    end
  end
end
