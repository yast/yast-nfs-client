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
require "cwm/rspec"
require "y2nfs_client/widgets/nfs_form"
require "y2nfs_client/widgets/nfs_version"
require "y2storage/filesystems/legacy_nfs"
require "y2storage/filesystems/nfs_version"

Yast.import "Nfs"

describe Y2NfsClient::Widgets::NfsForm do
  subject { described_class.new(nfs, nfs_entries) }

  let(:entry) do
    {
      "device" => "nfs.example.com:/test",
      "mount"  => "/mnt/test"
    }
  end

  let(:nfs) { Y2Storage::Filesystems::LegacyNfs.new_from_hash(entry) }
  let(:nfs_entries) { [] }

  before do
    allow(Yast::UI).to receive(:QueryWidget).and_return("")
    allow(Yast2::Popup).to receive(:show)
  end

  include_examples "CWM::CustomWidget"

  describe "#handle" do
    let(:event) { { "ID" => event_id } }

    before do
      allow(Yast::UI).to receive(:OpenDialog).and_return(true)
      allow(Yast::UI).to receive(:CloseDialog)
      allow(Yast::UI).to receive(:WidgetExists).and_return(true)
      allow(Yast::UI).to receive(:UserInput).and_return(input)
    end

    let(:input) { :cancel }

    context "when using the button for selecting the remote directory" do
      let(:event_id) { :pathent_list }

      before do
        allow(Yast::UI).to receive(:QueryWidget).with(Id(:serverent), :Value).and_return(nfs.server)

        allow_any_instance_of(Y2NfsClient::Widgets::NfsVersion).to receive(:value).and_return(version)

        allow(Yast::Nfs).to receive(:ProbeExports).and_return(exports)
      end

      let(:version) { Y2Storage::Filesystems::NfsVersion.find_by_value("3") }

      let(:exports) { [] }

      it "scans exports" do
        expect(Yast::Nfs).to receive(:ProbeExports)

        subject.handle(event)
      end

      context "when scan succeeds" do
        let(:exports) { ["/data", "/photos"] }

        context "and the user selects a directory" do
          let(:input) { :ok }

          let(:export) { exports.first }

          before do
            allow(Yast::UI).to receive(:QueryWidget).with(Id(:items), :CurrentItem).and_return(export)
          end

          it "sets the directory selected by the user" do
            expect(Yast::UI).to receive(:ChangeWidget).with(Id(:pathent), :Value, export)

            subject.handle(event)
          end
        end

        context "and the user cancels the selection" do
          let(:input) { :cancel }

          it "does not change the directory" do
            expect(Yast::UI).to_not receive(:ChangeWidget).with(Id(:pathent), any_args)

            subject.handle(event)
          end
        end
      end

      context "when scan fails" do
        let(:exports) { nil }

        it "reports an error" do
          expect(Yast::Report).to receive(:Error).with(/scan failed/)

          subject.handle(event)
        end
      end
    end

    context "when using the button for selecting the server" do
      let(:event_id) { :choose }

      before do
        allow(Yast::Nfs).to receive(:ProbeServers).and_return(servers)

        allow(Y2Firewall::Firewalld.instance).to receive(:running?).and_return(true)
      end

      let(:servers) { ["nfs.example.com"] }

      it "scans servers" do
        expect(Yast::Nfs).to receive(:ProbeServers)

        subject.handle(event)
      end

      context "when scan succeeds" do
        let(:servers) { ["nfs1.example.com", "nfs2.example.com"] }

        context "and the user selects a server" do
          let(:input) { :ok }

          let(:server) { servers.first }

          before do
            allow(Yast::UI).to receive(:QueryWidget).with(Id(:items), :CurrentItem).and_return(server)
          end

          it "sets the server selected by the user" do
            expect(Yast::UI).to receive(:ChangeWidget).with(Id(:serverent), :Value, server)

            subject.handle(event)
          end
        end

        context "and the user cancels the selection" do
          let(:input) { :cancel }

          it "does not change server" do
            expect(Yast::UI).to_not receive(:ChangeWidget).with(Id(:serverent), any_args)

            subject.handle(event)
          end
        end
      end

      context "when scan fails" do
        let(:servers) { [] }

        it "reports an error" do
          expect(Yast::Report).to receive(:Error).with(/No NFS server/)

          subject.handle(event)
        end
      end
    end

    context "when using the button for selecting the mount point" do
      let(:event_id) { :browse }

      before do
        allow(Yast::UI).to receive(:QueryWidget).with(Id(:mountent), :Value)

        allow(Yast::UI).to receive(:AskForExistingDirectory).and_return(dir)
      end

      let(:dir) { nil }

      it "ask for selecting a mount point" do
        expect(Yast::UI).to receive(:AskForExistingDirectory)

        subject.handle(event)
      end

      context "if the user selects a mount point" do
        let(:dir) { "/mnt" }

        it "sets the mount point selected by the user" do
          expect(Yast::UI).to receive(:ChangeWidget).with(Id(:mountent), :Value, dir)

          subject.handle(event)
        end
      end

      context "if the user does not select a mount point" do
        let(:dir) { nil }

        it "does not change the mount point" do
          expect(Yast::UI).to_not receive(:ChangeWidget).with(Id(:mountent), any_args)

          subject.handle(event)
        end
      end
    end
  end

  describe "#run?" do
    before do
      allow(nfs).to receive(:legacy_version?).and_return(legacy)
    end

    context "if the NFS is not using a legacy version" do
      let(:legacy) { false }

      it "returns true" do
        expect(subject.run?).to eq(true)
      end
    end

    context "if the NFS is using a legacy version" do
      let(:legacy) { true }

      before do
        allow(Yast2::Popup).to receive(:show).and_return(user_selection)
      end

      let(:user_selection) { :cancel }

      it "asks the user whether to continue" do
        expect(Yast2::Popup).to receive(:show).with(/Proceed and edit?/, any_args)

        subject.run?
      end

      context "and the user accepts" do
        let(:user_selection) { :continue }

        it "returns true" do
          expect(subject.run?).to eq(true)
        end
      end

      context "and the user cancels" do
        let(:user_selection) { :cancel }

        it "returns false" do
          expect(subject.run?).to eq(false)
        end
      end
    end
  end

  describe "#store" do
    before do
      allow(subject).to receive(:server).and_return("nfs.example.com")
      allow(subject).to receive(:remote_path).and_return("/data")
      allow(subject).to receive(:mount_path).and_return("/mnt")
      allow(subject).to receive(:mount_options).and_return("rw,fsck")
    end

    let(:nfs) { Y2Storage::Filesystems::LegacyNfs.new }

    it "sets the selected server to the NFS" do
      subject.store

      expect(nfs.server).to eq("nfs.example.com")
    end

    it "sets the selected remote directory to the NFS" do
      subject.store

      expect(nfs.path).to eq("/data")
    end
    it "sets the selected mount point to the NFS" do
      subject.store

      expect(nfs.mountpoint).to eq("/mnt")
    end
    it "sets the selected mount options to the NFS" do
      subject.store

      expect(nfs.fstopt).to eq("rw,fsck")
    end
  end
end
