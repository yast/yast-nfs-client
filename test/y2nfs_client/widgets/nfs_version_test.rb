#!/usr/bin/env rspec

# Copyright (c) [2022] SUSE LLC
#
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of version 2 of the GNU General Public License as published
# by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, contact SUSE LLC.
#
# To contact SUSE LLC about this file by physical or electronic mail, you may
# find current contact information at www.suse.com

require_relative "../../spec_helper"
require "y2nfs_client/widgets/nfs_version"
require "y2storage/filesystems/nfs_version"

describe Y2NfsClient::Widgets::NfsVersion do
  subject { described_class.new(initial_version) }

  let(:initial_version) { Y2Storage::Filesystems::NfsVersion.find_by_value("4") }

  describe "#contents" do
    def items(contents)
      contents.params.last
    end

    def find_item(contents, value)
      items(contents).find { |i| i.params.first.params.first == value }
    end

    it "returns a combobox" do
      expect(subject.contents).to be_a(Yast::Term)
      expect(subject.contents.value).to eq(:ComboBox)
    end

    it "includes an option for each NFS version" do
      contents = subject.contents

      expect(find_item(contents, "any")).to_not be_nil
      expect(find_item(contents, "3")).to_not be_nil
      expect(find_item(contents, "4")).to_not be_nil
      expect(find_item(contents, "4.1")).to_not be_nil
      expect(find_item(contents, "4.2")).to_not be_nil
    end

    it "does not include more options" do
      contents = subject.contents

      expect(items(contents).size).to eq(5)
    end
  end

  describe "#value" do
    before do
      allow(Yast::UI).to receive(:QueryWidget).and_return("3", "4.1")
    end

    it "returns a NfsVersion object" do
      expect(subject.value).to be_a(Y2Storage::Filesystems::NfsVersion)
    end

    it "returns the selected version" do
      expect(subject.value.value).to eq("3")
      expect(subject.value.value).to eq("4.1")
    end
  end
end
