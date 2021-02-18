#!/usr/bin/env rspec

# Copyright (c) [2017-2020] SUSE LLC
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

module Yast
  # just a wrapper class for the nfs/routines.rb
  class NfsRoutinesIncludeTesterClass < Module
    extend Yast::I18n

    def main
      Yast.include self, "nfs/routines.rb"
    end
  end
end

describe "Yast::NfsRoutinesInclude" do
  subject { Yast::NfsRoutinesIncludeTesterClass.new }
  let(:nfs_entries) do
    [
      {
        "file"    => "/home",
        "freq"    => 0,
        "mntops"  => "defaults",
        "passno"  => 0,
        "spec"    => "foo.bar.com:/home",
        "vfstype" => "nfs4"
      },
      {
        "file"    => "/var/spool/mail",
        "freq"    => 0,
        "mntops"  => "defaults",
        "passno"  => 0,
        "spec"    => "foo.bar.com:/var/spool/mail",
        "vfstype" => "nfs"
      },
      {
        "file"    => "/install",
        "freq"    => 0,
        "mntops"  => "hard,intr",
        "passno"  => 0,
        # different from "file" (for order tests)
        "spec"    => "foo.bar.com.tw:/local/install",
        "vfstype" => "nfs"
      }
    ]
  end

  before do
    subject.main
  end

  describe "#SpecToServPath" do
    let(:term) { subject.SpecToServPath(spec) }

    RSpec.shared_examples "couple term" do
      it "returns a :couple term" do
        expect(term).to be_a Yast::Term
        expect(term.value).to eql(:couple)
      end
    end

    context "for a spec with url and path separated by colon" do
      let(:spec) { "big.foo.com:/share/data" }

      include_examples "couple term"

      it "returns a term in which the params are the url and the path" do
        expect(term.params).to eql ["big.foo.com", "/share/data"]
      end
    end

    context "for a spec with url followed by a colon but no path" do
      let(:spec) { "big.foo.com:" }

      include_examples "couple term"

      it "returns a term in which the params are the url and an empty string" do
        expect(term.params).to eql ["big.foo.com", ""]
      end
    end

    context "for a spec with a string that looks like an url and no colon" do
      let(:spec) { "big.foo.com" }

      include_examples "couple term"

      it "returns a term in which the params are an empty string and the full spec" do
        expect(term.params).to eql ["", "big.foo.com"]
      end
    end

    context "for a spec with a string that looks like a path and no colon" do
      let(:spec) { "/nocolon/only/path" }

      include_examples "couple term"

      it "returns a term in which the params are an empty string and the full spec" do
        expect(term.params).to eql ["", "/nocolon/only/path"]
      end
    end

    context "for a spec containing only a colon followed by a path" do
      let(:spec) { ":/only/path" }

      include_examples "couple term"

      it "returns a term in which the params are an empty string and the path" do
        expect(term.params).to eql ["", "/only/path"]
      end
    end

    context "for a spec containing an IPv6 address (several colons) followed by a colon and a path" do
      let(:spec) { "fe80::219:d1ff:feac:fd10:/path" }

      include_examples "couple term"

      it "returns a term in which the params are the IP address (including all its colons) and the path" do
        expect(term.params).to eql ["fe80::219:d1ff:feac:fd10", "/path"]
      end
    end

    context "for an empty spec" do
      let(:spec) { "" }

      include_examples "couple term"

      it "returns a term in which the params are two empty strings" do
        expect(term.params).to eql ["", ""]
      end
    end
  end

  describe "#StripExtraSplash" do
    it "returns the striped path" do
      expect(subject.StripExtraSlash("")).to eql("")
      expect(subject.StripExtraSlash("/")).to eql("/")
      expect(subject.StripExtraSlash("/path")).to eql("/path")
      expect(subject.StripExtraSlash("/path/")).to eql("/path")
    end
  end

  describe "#FstabTableItems" do
    before do
      Y2Storage::StorageManager.create_test_instance
    end

    let(:working_graph) { Y2Storage::StorageManager.instance.staging }

    context "given a list of nfs fstab entries" do
      it "returns a list of ui table items" do
        items = subject.FstabTableItems(nfs_entries)

        expect(items.size).to eql(3)
        expect(items.first.params[1]).to eql("foo.bar.com ")
        expect(items.first.params[2]).to eql("/home ")
        expect(items.first.params[3]).to eql("/home* ")
        expect(items.first.params[4]).to eql("Any (Please Check) ")
        expect(items.first.params[5]).to eql("defaults ")
      end

      context "and an entry corresponds to a mounted NFS share" do
        before do
          nfs = Y2Storage::Filesystems::Nfs.create(working_graph, "srv", "/home/test")
          nfs.mount_path = "/home/test"
          nfs.mount_point.active = true
        end

        let(:nfs_entries) do
          [
            {
              "spec"    => "srv:/home/test",
              "file"    => "/home/test",
              "freq"    => 0,
              "mntops"  => "defaults",
              "passno"  => 0,
              "vfstype" => "nfs"
            }
          ]
        end

        it "does not append an asterisk to the mount path of the mounted NFS share" do
          # Note that the mount point of "srv:/home/test" is active
          items = subject.FstabTableItems(nfs_entries)

          expect(items.first.params[1]).to eql("srv ")
          expect(items.first.params[2]).to eql("/home/test ")
          expect(items.first.params[3]).to eql("/home/test ")
        end
      end

      context "and an entry corresponds to an unmounted NFS share" do
        before do
          nfs = Y2Storage::Filesystems::Nfs.create(working_graph, "srv", "/home/test")
          nfs.mount_path = "/home/test"
          nfs.mount_point.active = false
        end

        let(:nfs_entries) do
          [
            {
              "spec"    => "srv:/home/test",
              "file"    => "/home/test",
              "freq"    => 0,
              "mntops"  => "defaults",
              "passno"  => 0,
              "vfstype" => "nfs",
              "new"     => new_entry
            }
          ]
        end

        context "and the entry is new" do
          let(:new_entry) { true }

          it "does not append an asterisk to the mount path of the new NFS share" do
            # Note that the mount point of "srv:/home/test" is inactive
            items = subject.FstabTableItems(nfs_entries)

            expect(items.first.params[1]).to eql("srv ")
            expect(items.first.params[2]).to eql("/home/test ")
            expect(items.first.params[3]).to eql("/home/test ")
          end
        end

        context "and the entry is not new" do
          let(:new_entry) { false }

          it "appends an asterisk to the mount path of the unmounted NFS share" do
            # Note that the mount point of "srv:/home/a" is inactive
            items = subject.FstabTableItems(nfs_entries)

            expect(items.first.params[1]).to eql("srv ")
            expect(items.first.params[2]).to eql("/home/test ")
            expect(items.first.params[3]).to eql("/home/test* ")
          end
        end
      end
    end
  end

  describe "IsMpInFstab" do
    context "given a list of fstab nfs entries and an mount point" do
      before do
        allow(Yast::Report).to receive(:Error)
        allow(subject).to receive(:non_nfs_mount_paths).and_return([])
      end

      context "when the given mount point is present in fstab" do
        it "returns true" do
          expect(subject.IsMpInFstab(nfs_entries, "/home")).to eql(true)
          expect(subject.IsMpInFstab(nfs_entries, "/install")).to eql(true)
        end

        it "reports an error" do
          expect(Yast::Report).to receive(:Error).with(/fstab already contains/)
          subject.IsMpInFstab(nfs_entries, "/home")
        end
      end
      context "when the given mount point is not present in fstab" do
        it "returns false" do
          expect(subject.IsMpInFstab(nfs_entries, "/not/in/fstab")).to eql(false)
        end
      end
    end
  end

  describe "#CheckPath" do
    let(:path) { "a" * 68 }

    context "when the given path size is in the 1..69 range" do
      context "and begins with a slash" do
        it "returns true" do
          expect(subject.CheckPath("/#{path}")).to eq(true)
        end
      end
      context "and does not begin with a slash" do
        before do
          allow(Yast::Report).to receive(:Error)
        end

        it "returns false" do
          expect(subject.CheckPath(path.to_s)).to eq(false)
        end

        it "reports and error" do
          expect(Yast::Report).to receive(:Error).with(/The path entered is invalid/)
          subject.CheckPath(path.to_s)
        end
      end
    end
    context "when the given path size is out of the 1..69 range" do
      before do
        allow(Yast::Report).to receive(:Error)
      end

      it "reports and error" do
        expect(Yast::Report).to receive(:Error).with(/The path entered is invalid/)
        subject.CheckPath("/#{path}/verylong")
      end

      it "returns false" do
        expect(subject.CheckPath("/#{path}/verylong")).to eq(false)
      end
    end
  end

  describe "#CheckHostName" do
    let(:too_long_name) { "123456789" * 10 }
    let(:valid_ipv6_names) do
      [
        "fe80::219:d1ff:feac:fd10",
        "[::1]",
        "fe80::3%eth0",
        "[fe80::3%eth0]"
      ]
    end
    let(:invalid_names) do
      [
        "Wrong:Server:Name",
        "[::1",
        "192.168.10:1",
        "[fe80::3%]"
      ]
    end

    before do
      allow(Yast::Report).to receive(:Error)
    end

    context "when the given name is between 1 and 49 characteres" do
      it "returns true if it is a valid IPv4" do
        expect(subject.CheckHostName("192.168.0.1")).to eql(true)
      end

      it "returns true if it is a valid IPv6" do
        valid_ipv6_names.map do |name|
          expect(subject.CheckHostName(name)).to eql(true)
        end
      end

      it "returns true if it is a valid domain" do
        expect(subject.CheckHostName("nfs-server.suse.com")).to eql(true)
      end

      context "and was not validated previously" do
        it "reports an error" do
          invalid_names.map do |name|
            expect(Yast::Report).to receive(:Error).with(/The hostname entered is invalid/)
            subject.CheckHostName(name)
          end
        end

        it "returns false" do
          invalid_names.map do |name|
            expect(subject.CheckHostName(name)).to eql(false)
          end
        end
      end
    end

    context "when the given name size is out of 1..49 range" do
      it "reports and error" do
        expect(Yast::Report).to receive(:Error).with(/The hostname entered is invalid/)

        subject.CheckHostName(too_long_name)
      end

      it "returns false" do
        expect(subject.CheckHostName(too_long_name)).to eql(false)
      end
    end
  end

  describe "#FormatHostnameForFstab" do
    it "encloses the given hostname into brackets in case of a IPv6 one" do
      expect(subject.FormatHostnameForFstab("::1")).to eql("[::1]")
      expect(subject.FormatHostnameForFstab("[::1]")).to eql("[::1]")
      expect(subject.FormatHostnameForFstab("127.0.0.1")).to eql("127.0.0.1")
      expect(subject.FormatHostnameForFstab("suse.de")).to eql("suse.de")
    end
  end
end
