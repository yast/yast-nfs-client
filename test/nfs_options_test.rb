#! /usr/bin/env rspec

ENV["Y2DIR"] = File.expand_path("../../src", __FILE__)

require "yast"

Yast.import "NfsOptions"

describe "#validate" do
  it "returns empty message on correct options" do
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

  it "returns error message on incorrect options" do
    [
      "",
      "nolock, bg",
      "nolock,unknownoption",
      "nolock,unknownassignment=true",
      "nolock,rsize=",
      "nolock,two=equal=signs",
      "nolock,retrans=trans=trans",
      "nolock,intr=bogus",
    ].each do |options|
      returned = Yast::NfsOptions.validate(options)
      expect(returned).not_to be_empty, "options '#{options}' returned '#{returned}'"
    end
  end

  it "returns error message on incorrect options" do
    [
      "noatime,port=",
      "mountvers=",
      "mountvers,=port=23",
    ].each do |options|
      returned = Yast::NfsOptions.validate(options)
      expect(returned).to start_with("Empty value"), "options '#{options}' returned '#{returned}'"
    end

    [
      "noatime,port=dort=fort",
      "mountvers=port=23",
    ].each do |options|
      returned = Yast::NfsOptions.validate(options)
      expect(returned).to start_with("Invalid option"), "options '#{options}' returned '#{returned}'"
    end

    [
      "noatime,unknownparam",
      "mountvers2",
    ].each do |options|
      returned = Yast::NfsOptions.validate(options)
      expect(returned).to start_with("Unknown option"), "options '#{options}' returned '#{returned}'"
    end
  end
end
