#!/usr/bin/env rspec

# Copyright (c) [2015-2020] SUSE LLC
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

require_relative "spec_helper"
require "yaml"
require "y2firewall/firewalld"

Yast.import "Nfs"
Yast.import "Progress"
Yast.import "Service"

describe "Yast::Nfs" do
  def allow_read_side_effects
    allow(subject).to receive(:ReadNfs4)
    allow(subject).to receive(:ReadNfsGss)
    allow(subject).to receive(:ReadIdmapd)
    allow(subject).to receive(:FindPortmapper).and_return("rpcbind")
    allow(subject).to receive(:firewalld).and_return(firewalld)
    allow(firewalld).to receive(:read)
    allow(subject).to receive(:check_and_install_required_packages)
  end

  def add_nfs_devices
    nfs1 = Y2Storage::Filesystems::Nfs.create(working_graph, "nfs.example.com", "/foo")
    nfs1.mount_path = "/foo"

    nfs2 = Y2Storage::Filesystems::Nfs.create(working_graph, "nfs.example.com", "/baz")
    nfs2.mount_path = "/foo/bar/baz"
  end

  def mock_entries
    add_nfs_devices

    subject.skip_fstab = false
    subject.Read
  end

  before do
    # Load local devices
    sm = Y2Storage::StorageManager.create_test_instance
    sm.probe_from_yaml(File.join(DATA_PATH, "devicegraph.yaml"))

    # Prevent further reprobing
    allow(sm).to receive(:probe).and_return true

    # prevent storage-commit
    allow(sm).to receive(:commit)
  end

  subject { Yast::Nfs }

  let(:firewalld) { Y2Firewall::Firewalld.instance }

  let(:working_graph) { Y2Storage::StorageManager.instance.staging }

  describe ".Import" do
    let(:profile) do
      {
        "enable_nfs4"    => true,
        "enable_nfs_gss" => true,
        "nfs_entries"    => [
          {
            "server_path" => "data.example.com:/mirror",
            "mount_point" => "/mirror",
            "nfs_options" => "defaults"
          }
        ]
      }
    end

    # bnc#820989
    let(:profile_SLE11) do
      [
        {
          "enable_nfs_gss" => true,
          "idmapd_domain"  => "example.com"
        },
        {
          "server_path" => "data.example.com:/mirror",
          "mount_point" => "/mirror",
          "nfs_options" => "defaults"
        }
      ]
    end

    before do
      subject.nfs_entries = []
      subject.nfs4_enabled = false
    end

    context "when all the nfs entries given in the profile are valid" do
      it "imports the nfs entries defined in the profile" do
        subject.Import(profile)
        expect(subject.nfs_entries.size).to eql(1)
        expect(subject.nfs_entries.first["spec"]).to eql("data.example.com:/mirror")
      end

      it "imports the global options when defined as a list" do
        subject.Import(profile)
        expect(subject.nfs4_enabled).to eql(true)
        expect(subject.nfs_gss_enabled).to eql(true)
      end

      it "imports the global options when defined as a map" do
        subject.Import(profile_SLE11)
        expect(subject.nfs_gss_enabled).to eql(true)
        expect(subject.idmapd_domain).to eql("example.com")
      end

      context "and some of the entries defines the nfs_version=4 in the nfs_options" do
        it "enables nfs4 globaly even if it was missing in the profile" do
          profile_SLE11.last["nfs_options"] = "nfsvers=4"
          expect(subject.Import(profile_SLE11)).to eql(true)
          expect(subject.nfs_entries.size).to eql(1)
          expect(subject.nfs4_enabled).to eql(true)
        end
      end
    end

    context "when some of the nfs entries does not contain all the mandatory fields " do
      let(:profile) { { "nfs_entries" => [{ "server_path" => "data.example.com:/mirror" }] } }

      it "does not import the incomplete nfs entries " do
        subject.Import(profile)
        expect(subject.nfs_entries.size).to eql(0)
      end

      it "returns false" do
        expect(subject.Import(profile)).to eql(false)
      end
    end
  end

  describe ".Export" do
    before do
      mock_entries
      subject.nfs4_enabled = true
      subject.nfs_gss_enabled = false
      subject.idmapd_domain = "example.com"
    end

    let(:expected_profile) do
      {
        "enable_nfs4"    => true,
        "enable_nfs_gss" => false,
        "idmapd_domain"  => "example.com",
        "nfs_entries"    => [
          {
            "server_path" => "nfs.example.com:/foo",
            "mount_point" => "/foo",
            "vfstype"     => "nfs",
            "nfs_options" => "defaults"
          },
          {
            "server_path" => "nfs.example.com:/baz",
            "mount_point" => "/foo/bar/baz",
            "vfstype"     => "nfs",
            "nfs_options" => "defaults"
          }
        ]
      }
    end

    it "exports the current nfs settings as a map" do
      profile = subject.Export()

      expect(profile).to eql(expected_profile)
    end
  end

  describe ".Read" do
    before do
      subject.skip_fstab = true
      subject.nfs4_enabled = true
      subject.nfs_gss_enabled = true
      allow_read_side_effects
    end

    context "when the read of fstab is not set to be skipped" do
      before do
        subject.skip_fstab = false
        allow(subject).to receive(:storage_probe).and_return(true)
        allow(subject).to receive(:storage_nfs_mounts).and_return([])
      end

      it "triggers a storage reprobing returning false if fails" do
        expect(subject).to receive(:storage_probe).and_return(false)
        expect(subject.Read()).to eql(false)
      end

      it "loads the nfs entries with the information provided by the storage layer" do
        expect(subject).to receive(:load_nfs_entries).with([])
        subject.Read
      end
    end

    it "reads if nfs4 is supported in sysconfig" do
      expect(subject).to receive(:ReadNfs4).and_return(false)
      expect(subject.nfs4_enabled).to eql(true)
      subject.Read
      expect(subject.nfs4_enabled).to eql(false)
    end

    it "reads if nfs gss security is enabled in sysconfig" do
      expect(subject).to receive(:ReadNfsGss).and_return(false)
      expect(subject.nfs_gss_enabled).to eql(true)
      subject.Read
      expect(subject.nfs_gss_enabled).to eql(false)
    end

    it "checks which is the portmapper in use" do
      expect(subject).to receive(:FindPortmapper)
      subject.Read
    end

    it "reads the firewalld configuration" do
      expect(firewalld).to receive(:read)
      subject.Read
    end

    it "checks and/or install required nfs-client packages" do
      expect(subject).to receive(:check_and_install_required_packages)
      subject.Read
    end
  end

  describe ".WriteOnly" do
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
        .with(path(".target.bash"), %r{^/usr/bin/cp }, any_args)

      # Load the lists
      allow_read_side_effects
      mock_entries
    end

    def nfs(share)
      working_graph.nfs_mounts.find { |n| n.share == share }
    end

    def entry(spec)
      subject.nfs_entries.find { |e| e["spec"] == spec }
    end

    def create_entry(spec)
      {
        "spec"    => spec,
        "file"    => "/home/test",
        "freq"    => 0,
        "mntops"  => "defaults",
        "passno"  => 0,
        "vfstype" => "nfs"
      }
    end

    def find_mp(path)
      working_graph.filesystems.find { |fs| fs.mount_path == path }.mount_point
    end

    it "ensures zero for the 'passno' field, only in nfs entries" do
      # Enforce weird passno value for NFS
      find_mp("/foo").to_storage_value.passno = 1
      find_mp("/foo/bar/baz").to_storage_value.passno = 2

      expect(find_mp("/").passno).to eq 1
      expect(find_mp("/foof").passno).to eq 2
      expect(find_mp("/foo").passno).to eq 1
      expect(find_mp("/foo/bar/baz").passno).to eq 2

      subject.WriteOnly

      expect(find_mp("/").passno).to eq 1
      expect(find_mp("/foof").passno).to eq 2
      expect(find_mp("/foo").passno).to eq 0
      expect(find_mp("/foo/bar/baz").passno).to eq 0
    end

    shared_examples "remove_entry" do
      it "removes the existing NFS share" do
        nfs_sid = nfs(spec).sid

        subject.WriteOnly

        expect(working_graph.find_device(nfs_sid)).to be_nil
      end
    end

    context "when the entry is new" do
      before do
        entry = entry(spec)

        if entry
          entry["new"] = true
        else
          entry = create_entry(spec)
          entry["new"] = true
          subject.nfs_entries << entry
        end
      end

      shared_examples "new_entry" do
        it "creates a new NFS share for that entry" do
          subject.WriteOnly

          nfs = nfs(spec)

          expect(nfs).to_not be_nil
          expect(nfs.exists_in_probed?).to eq(false)
        end

        it "sets the NFS mount point as active" do
          subject.WriteOnly

          nfs = nfs(spec)

          expect(nfs.mount_point.active?).to eq(true)
        end

        it "sets the NFS to be written to the fstab" do
          subject.WriteOnly

          nfs = nfs(spec)

          expect(nfs.mount_point.in_etc_fstab?).to eq(true)
        end
      end

      context "and the NFS share does no exist in the system yet" do
        let(:spec) { "nfs.example.com:/home/test" }

        include_examples "new_entry"
      end

      context "and the NFS share already exists in the system" do
        let(:spec) { "nfs.example.com:/foo" }

        before do
          # Set mount point properties of the existing NFS share. This configuration should not be
          # propagated to the new NFS share.
          nfs = nfs(spec)
          nfs.mount_point.active = false
          nfs.mount_point.in_etc_fstab = false
        end

        include_examples "remove_entry"

        include_examples "new_entry"
      end
    end

    context "when the entry is not new" do
      before do
        entry = entry(spec)
        entry["new"] = false
      end

      let(:spec) { "nfs.example.com:/foo" }

      include_examples "remove_entry"

      context "and the entry corresponds to a mounted NFS share" do
        before do
          nfs(spec).mount_point.active = true
        end

        it "creates a NFS share with active mount point" do
          subject.WriteOnly

          expect(nfs(spec).mount_point.active?).to eq(true)
        end
      end

      context "and the entry corresponds to an unmounted NFS share" do
        before do
          nfs(spec).mount_point.active = false
        end

        it "creates a NFS share with inactive mount point" do
          subject.WriteOnly

          expect(nfs(spec).mount_point.active?).to eq(true)
        end
      end

      context "and the entry corresponds to a NFS share included in the fstab" do
        before do
          nfs(spec).mount_point.in_etc_fstab = true
        end

        it "creates a NFS share that would be written to the fstab" do
          subject.WriteOnly

          expect(nfs(spec).mount_point.in_etc_fstab?).to eq(true)
        end
      end

      context "and the entry corresponds to a NFS that is not included in the fstab" do
        before do
          nfs(spec).mount_point.in_etc_fstab = true
        end

        it "creates a NFS share that would not be written to the fstab" do
          subject.WriteOnly

          expect(nfs(spec).mount_point.in_etc_fstab?).to eq(false)
        end
      end
    end
  end

  describe ".Write" do
    before do
      allow(subject).to receive(:WriteOnly).and_return(written)

      allow(Yast::Wizard)
      allow(Yast::Progress).to receive(:set)
      allow(Yast::Service).to receive(:Start)
      allow(Yast::Service).to receive(:Stop)
      allow(Yast::Service).to receive(:active?)

      allow_read_side_effects
      mock_entries
    end

    let(:written) { false }

    it "writes the nfs configurations" do
      expect(subject).to receive(:WriteOnly)
      subject.Write()
    end

    context "when the configuration is written correctly" do
      let(:written) { true }

      it "tries to start the portmapper service if it is not running" do
        expect(Yast::Service).to receive(:active?).with("rpcbind").and_return(false)
        expect(Yast::Service).to receive(:Start).with("rpcbind")
        subject.Write()
      end

      context "and the portmapper service was not activated" do
        before do
          allow(Yast::Service).to receive(:active?).with("rpcbind").twice.and_return(false)
          allow(Yast::Message).to receive(:CannotStartService).and_return("cannot_start")
        end

        it "reports an error" do
          expect(Yast::Report).to receive(:Error).with("cannot_start")

          subject.Write
        end

        it "returns false" do
          expect(subject.Write).to eql(false)
        end
      end
    end

    context "when the configuration is not written correctly" do
      before do
        allow(subject).to receive(:WriteOnly).and_return(false)
      end

      it "returns false" do
        expect(subject.Write).to eql(false)
      end
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
