#! /usr/bin/env rspec
# Copyright (c) 2014 SUSE Linux.
#  All Rights Reserved.

#  This program is free software; you can redistribute it and/or
#  modify it under the terms of version 2 or 3 of the GNU General
#  Public License as published by the Free Software Foundation.

#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.   See the
#  GNU General Public License for more details.

#  You should have received a copy of the GNU General Public License
#  along with this program; if not, contact SUSE LLC.

#  To contact SUSE about this file by physical or electronic mail,
#  you may find current contact information at www.suse.com

require_relative "spec_helper"

Yast.import "NfsOptions"

describe "Yast::NfsOptions" do
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
        "nolock,rsize="
      ].each do |options|
        returned = Yast::NfsOptions.validate(options)
        expect(returned).to start_with("Empty value"), "options '#{options}' returned '#{returned}'"
      end
    end

    it "returns 'Unexpected value' error message on options that do not expect any value" do
      [
        "nolock,intr=bogus",
        "nosuid=true"
      ].each do |options|
        returned = Yast::NfsOptions.validate(options)
        expect(returned).to start_with("Unexpected value"), "options '#{options}' returned '#{returned}'"
      end
    end

    it "returns 'Invalid option' error message on options that expect key=value and the value contains '='" do
      [
        "noatime,port=dort=fort",
        "mountvers=port=23",
        "nolock,retrans=trans=trans"
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
        "nolock,two=equal=signs"
      ].each do |options|
        returned = Yast::NfsOptions.validate(options)
        expect(returned).to start_with("Unknown option"), "options '#{options}' returned '#{returned}'"
      end
    end
  end

  describe "#nfs_version" do
    it "returns the generic version if none of vers or nfsvers is used" do
      [
        "defaults",
        "nolock,bg",
        "nolock,minorversion=1",
        "nolock,rsize=8192",
        "defaults,ro,noatime,minorversion=1,users,exec"
      ].each do |options|
        returned = Yast::NfsOptions.nfs_version(options)
        expect(returned.mntops_value).to be_nil
      end
    end

    it "returns the version specified by nfsvers if it's present" do
      {
        "nfsvers=4"                => "4",
        "nfsvers=4,minorversion=1" => "4",
        "nfsvers=4.0"              => "4",
        "nfsvers=4.2"              => "4.2",
        "defaults,nfsvers=3"       => "3",
        "nfsvers=4.1,nolock"       => "4.1"
      }.each_pair do |opts, version|
        returned = Yast::NfsOptions.nfs_version(opts)
        expect(returned.mntops_value).to eq version
      end
    end

    it "returns the version specified by vers if it's present" do
      {
        "minorversion=1,vers=4" => "4",
        "vers=3,ro"             => "3",
        "vers=4.1"              => "4.1",
        "vers=4.2"              => "4.2"
      }.each_pair do |opts, version|
        returned = Yast::NfsOptions.nfs_version(opts)
        expect(returned.mntops_value).to eq version
      end
    end

    it "returns the correct version if nfsvers and vers appear several time" do
      {
        "nfsvers=4,minorversion=1,vers=3"        => "3",
        "vers=3,ro,vers=4"                       => "4",
        "vers=4.1,rw,nfsvers=3,nfsvers=4,nolock" => "4"
      }.each_pair do |opts, version|
        returned = Yast::NfsOptions.nfs_version(opts)
        expect(returned.mntops_value).to eq version
      end
    end

    it "raises ArgumentError if unknown version appears" do
      [
        "nfsvers=4.5",
        "vers=5,rw"
      ].each do |opts|
        expect { Yast::NfsOptions.nfs_version(opts) }.to raise_error(ArgumentError)
      end

    end
  end

  describe "#set_nfs_version" do
    def set_version(opts, version_value)
      version = Y2NfsClient::NfsVersion.for_mntops_value(version_value)
      Yast::NfsOptions.set_nfs_version(opts, version)
    end

    it "removes existing minorversion options" do
      expect(set_version("minorversion=1", nil)).to eq "defaults"
      expect(set_version("minorversion=1,ro,minorversion=1", "4")). to eq "ro,nfsvers=4"
    end

    it "removes nfsvers and vers when enforcing no particular version" do
      expect(set_version("nfsvers=4", nil)).to eq "defaults"
      expect(set_version("vers=3,ro", nil)). to eq "ro"
      expect(set_version("nolock,vers=4.1,rw,nfsvers=4", nil)). to eq "nolock,rw"
      expect(set_version("nolock,vers=4.2,rw,nfsvers=4", nil)). to eq "nolock,rw"
    end

    it "modifies the existing nfsvers or vers option if needed" do
      expect(set_version("nfsvers=4", "3")).to eq "nfsvers=3"
      expect(set_version("vers=3,ro", "4")). to eq "vers=4,ro"
      expect(set_version("nolock,nfsvers=4.1,rw,vers=4", "4.1")). to eq "nolock,rw,vers=4.1"
      expect(set_version("nolock,nfsvers=4.2,rw,vers=4", "4.2")). to eq "nolock,rw,vers=4.2"
    end

    it "deletes surplus useless nfsvers and vers options" do
      expect(set_version("vers=4,nolock,nfsvers=4.1,rw,vers=4", "4.1")). to eq "nolock,rw,vers=4.1"
      expect(set_version("nfsvers=4,vers=4.1,rw,nfsvers=4", "3")). to eq "rw,nfsvers=3"
    end

    it "adds a nfsvers if a new option is needed" do
      expect(set_version("defaults", "4.1")). to eq "nfsvers=4.1"
      expect(set_version("defaults", "4.2")). to eq "nfsvers=4.2"
      expect(set_version("rw,nolock", "3")). to eq "rw,nolock,nfsvers=3"
    end
  end
end
