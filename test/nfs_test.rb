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
require "y2firewall/firewalld"

Yast.import "Nfs"
Yast.import "Progress"
Yast.import "Service"

describe "Yast::Nfs" do
  subject { Yast::Nfs }

  describe ".WriteOnly" do
    let(:firewalld) { Y2Firewall::Firewalld.instance }
    let(:fstab_entries) { YAML.load_file(File.join(DATA_PATH, "fstab_entries.yaml")) }
    let(:nfs_entries) { fstab_entries.select { |e| e["vfstype"] == "nfs" } }

    before do
      # Set some sane defaults
      subject.nfs4_enabled = true
      subject.nfs_gss_enabled = true
      allow(subject).to receive(:FindPortmapper).and_return "portmap"

      # Stub some risky calls
      allow(subject).to receive(:firewalld).and_return(firewalld)
      allow(Yast::Progress).to receive(:set)
      allow(Yast::Service).to receive(:Enable)
      allow(Yast::SCR).to receive(:Execute)
        .with(path(".target.mkdir"), anything)
      allow(Yast::SCR).to receive(:Write)
        .with(path_matching(/^\.sysconfig\.nfs/), any_args)
      allow(Yast::SCR).to receive(:Write)
        .with(path_matching(/^\.etc\.idmapd_conf/), any_args)
      allow(firewalld).to receive(:installed?).and_return(true)
      allow(firewalld).to receive(:read)
      allow(firewalld).to receive(:write_only)
      # Creation of the backup
      allow(Yast::SCR).to receive(:Execute)
        .with(path(".target.bash"), %r{^/bin/cp }, any_args)

      # Load the lists
      subject.nfs_entries = nfs_entries
      allow(Yast::SCR).to receive(:Read).with(path(".etc.fstab"))
        .and_return fstab_entries
    end

    xit "ensures zero for 'passno' and 'freq' fields, only in nfs entries" do
      expected_passnos = {
        "/"            => 1,
        "/foof"        => nil,
        "/foo"         => 0,
        "/foo/bar"     => 0,
        "/foo/bar/baz" => 0
      }
      expected_freqs = {
        "/"            => nil,
        "/foof"        => 1,
        "/foo"         => 0,
        "/foo/bar"     => 2,
        "/foo/bar/baz" => 0
      }

      expect(Yast::SCR).to receive(:Write).with(path(".etc.fstab"), anything) do |_path, fstab|
        passnos = {}
        freqs = {}
        fstab.each do |e|
          passnos[e["file"]] = e["passno"]
          freqs[e["file"]] = e["freq"]
        end
        expect(passnos).to eq expected_passnos
        expect(freqs).to eq expected_freqs
      end

      subject.WriteOnly
    end
  end

  describe ".legacy_entry?" do
    let(:all_entries) { YAML.load_file(File.join(DATA_PATH, "nfs_entries.yaml")) }
    let(:entries) { all_entries.map { |e| [e["file"], e] }.to_h }

    it "returns true for entries using nfs4 as vfstype" do
      expect(subject.legacy_entry?(entries["/two"])).to eq true
      expect(subject.legacy_entry?(entries["/four"])).to eq true
    end

    it "returns true for entries using minorversion in the mount options" do
      expect(subject.legacy_entry?(entries["/four"])).to eq true
      expect(subject.legacy_entry?(entries["/five"])).to eq true
    end

    it "returns false for entries without nfs4 or minorversion" do
      expect(subject.legacy_entry?(entries["/one"])).to eq false
      expect(subject.legacy_entry?(entries["/three"])).to eq false
    end
  end
end
