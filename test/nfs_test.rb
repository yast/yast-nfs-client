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
require "yaml"
require "yast2/etc_fstab"

Yast.import "Nfs"
Yast.import "Progress"
Yast.import "SuSEFirewall"
Yast.import "Service"

describe Yast::Nfs do
  subject { Yast::Nfs }

  describe ".WriteOnly" do
    let(:fstab_name) { File.join(DATA_PATH, "generated_fstab") }
    let(:yaml_fstab_entries) { YAML.load_file(File.join(DATA_PATH, "fstab_entries.yaml")) }
    let(:nfs_entries) do
      entry_in_fstab =
        {
          "spec"    => "nfs.example.com:/baz",
          "file"    => "/foo/bar/baz",
          "vfstype" => "nfs",
          "mntops"  => "defaults"
        }
      entry_not_in_fstab =
        {
          "spec"    => "nfs.example.com:/foo",
          "file"    => "/foo",
          "vfstype" => "nfs",
          "mntops"  => "defaults"
        }
      [entry_in_fstab, entry_not_in_fstab]
    end

    # Create a hash with symbol keys from a hash with string keys
    # This is available in Rails, but not in plain Ruby.
    def symbolize_keys(str_hash)
      sym_hash = {}
      str_hash.each { |k, v| sym_hash[k.to_sym] = v }
      sym_hash
    end

    def create_fstab(filename, yaml_entries)
      fstab = EtcFstab.new
      yaml_entries.each do |yaml_entry|
        entry = fstab.create_entry(symbolize_keys(yaml_entry))
        fstab.add_entry(entry)
      end
      fstab.write(filename)
    end

    before do
      # Creating an fstab without any NFS entries in data/generated_fstab
      create_fstab(fstab_name, yaml_fstab_entries)

      # Use the test environment's fstab
      subject.etc_fstab_name = fstab_name

      # Set some sane defaults
      subject.nfs4_enabled = true
      subject.nfs_gss_enabled = true
      allow(subject).to receive(:FindPortmapper).and_return "portmap"

      # Stub some risky calls
      allow(Yast::SuSEFirewall).to receive(:WriteOnly)
      allow(Yast::Progress).to receive(:set)
      allow(Yast::Service).to receive(:Enable)
      allow(Yast::SCR).to receive(:Execute)
        .with(path(".target.mkdir"), anything)
      allow(Yast::SCR).to receive(:Write)
        .with(path_matching(/^\.sysconfig\.nfs/), any_args)
      allow(Yast::SCR).to receive(:Write)
        .with(path_matching(/^\.etc\.idmapd_conf/), any_args)
      # Creation of the backup
      allow(Yast::SCR).to receive(:Execute)
        .with(path(".target.bash"), %r{^/bin/cp }, any_args)

      # Load the lists
      subject.nfs_entries = nfs_entries
    end

    after do
      # Comment this out to debug unexpected behaviour
      File.delete(fstab_name)
    end

    it "creates a properly ordered fstab" do
      subject.WriteOnly

      ordered_mount_points = ["/", "/foo", "/foof", "/foo/bar", "/foo/bar/baz"]

      fstab = EtcFstab.new(fstab_name)
      expect(fstab.mount_points).to eq ordered_mount_points
    end

    it "ensures zero for 'passno' and 'freq' fields, only in nfs entries" do
      subject.WriteOnly
      fstab = EtcFstab.new(fstab_name)
      shares, other_entries = fstab.partition { |e| e.fs_type.start_with?("nfs") }

      expect(shares.size).to be == 2
      expect(shares.map(&:fsck_pass)).to eq [0, 0]
      expect(shares.map(&:dump_pass)).to eq [0, 0]

      expect(other_entries.size).to be == 3
      expect(other_entries.map(&:fsck_pass)).to eq [1, 1, 2]
      expect(other_entries.map(&:dump_pass)).to eq [1, 0, 0]
    end
  end
end
