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
end
