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
# find current contact information at www.suse.com.

require "cwm"
require "y2storage"
require "yast2/popup"
require "yast2/feedback"
require "y2nfs_client/widgets/nfs_version"

module Y2NfsClient
  module Widgets
    # Widget to set NFS options
    #
    # Most of the code in this widget comes directly from the old include file "nfs/ui.rb", so it
    # doesn't exactly complain with the standard way of structuring code in Y2Partitioner.
    class NfsForm < CWM::CustomWidget
      Yast.import "NfsOptions"

      # List of cached hosts
      #
      # @return [Array<String>, nil]
      attr_reader :hosts

      # Constructor
      #
      # @param nfs [Y2Storage::Filesystems::LegacyNfs] Object representing a nfs entry. This object is
      #   modified in #store method.
      # @param nfs_entries [Array<Y2Storage::Filesystems::LegacyNfs>] The rest of entries
      # @param hosts [Array<String>, nil] List of cached hosts. Passing a list avoids to perform a new
      #   search.
      def initialize(nfs, nfs_entries, hosts: nil)
        super()

        Yast.import "Nfs"
        Yast.import "NfsOptions"
        Yast.import "Hostname"
        Yast.import "FileUtils"
        Yast.include self, "nfs/routines.rb"

        textdomain "nfs"
        self.handle_all_events = true

        @nfs = nfs
        @server = nfs.server || ""
        @remote_path = nfs.path || ""
        @mount_path = nfs.mountpoint || ""
        @mount_options = nfs.fstopt || ""

        @nfs_entries = nfs_entries
        @hosts = hosts
      end

      # NFS being created or edited
      #
      # @return [Y2Storage::Filesystems::LegacyNfs]
      attr_reader :nfs

      # @macro seeAbstractWidget
      def contents
        VBox(
          VSpacing(0.2),
          HBox(
            text_and_button(
              ComboBox(
                Id(:serverent),
                Opt(:editable),
                # text entry label
                _("&NFS Server Hostname"),
                servers
              ),
              # pushbutton label
              # choose a host from a list
              # appears in help text too
              PushButton(Id(:choose), _("Choo&se"))
            ),
            HSpacing(0.5),
            text_and_button(
              InputField(
                Id(:pathent),
                Opt(:hstretch),
                # textentry label
                _("&Remote Directory"),
                remote_path
              ),
              # pushbutton label,
              # select from a list of remote filesystems
              # make it short
              # appears in help text too
              PushButton(Id(:pathent_list), _("&Select"))
            )
          ),
          Left(
            version_widget.contents
          ),
          Left(
            text_and_button(
              InputField(
                Id(:mountent),
                Opt(:hstretch),
                # textentry label
                _("&Mount Point (local)"),
                mount_path
              ),
              # button label
              # browse directories to select a mount point
              # appears in help text too
              PushButton(Id(:browse), _("&Browse"))
            )
          ),
          # textentry label
          VSpacing(0.2),
          InputField(Id(:optionsent), Opt(:hstretch), _("O&ptions"), mount_options)
        )
      end

      def init
        Yast::UI.ChangeWidget(Id(:serverent), :Value, server)
        Yast::UI.SetFocus(Id(:serverent))
      end

      # @macro seeAbstractWidget
      def handle(event)
        case event["ID"]
        when :choose
          handle_choose
        when :pathent_list
          handle_pathent_list
        when :browse
          handle_browse
        end
      end

      # Help text
      #
      # @return [String]
      def help
        # help text 1/4
        # change: locally defined -> servers on LAN
        _(
          "<p>Enter the <b>NFS Server Hostname</b>.  With\n" \
          "<b>Choose</b>, browse through a list of\n" \
          "NFS servers on the local network.</p>\n"
        ) +
          # help text 2/4
          # added "Select" button
          _(
            "<p>In <b>Remote File System</b>,\n" \
            "enter the path to the directory on the NFS server.  Use\n" \
            "<b>Select</b> to select one from those exported by the server.\n" \
            "</p>"
          ) +
          # help text 3/4
          _(
            "<p>\t\t\n" \
            "For <b>Mount Point</b>, enter the path in the local " \
            "file system where the directory should be mounted. With\n" \
            "<b>Browse</b>, select your mount point\n" \
            "interactively.</p>"
          ) +
          # help text 4/4
          _(
            "<p>For a list of <b>Options</b>,\nread the man page mount(8).</p>"
          )
      end

      # Validates the selected values
      #
      # Errors are shown to the user.
      #
      # @return [Boolean]
      def validate
        @server = FormatHostnameForFstab(Yast::UI.QueryWidget(Id(:serverent), :Value))
        @remote_path = StripExtraSlash(Yast::UI.QueryWidget(Id(:pathent), :Value))
        @mount_path = StripExtraSlash(Yast::UI.QueryWidget(Id(:mountent), :Value))
        set_mount_options(mount_options_from_widget, version_from_widget)

        options_error = Yast::NfsOptions.validate(mount_options)
        if !CheckHostName(server)
          Yast::UI.SetFocus(Id(:serverent))
        elsif !CheckPath(remote_path)
          Yast::UI.SetFocus(Id(:pathent))
        elsif !CheckPath(mount_path) || IsMpInFstab(fstab_entries, mount_path)
          Yast::UI.SetFocus(Id(:mountent))
        elsif !options_error.empty?
          Yast::Popup.Error(options_error)
          Yast::UI.SetFocus(Id(:optionsent))
        else
          return true
        end

        false
      end

      # Saves the selected values
      def store
        @nfs.server = server
        @nfs.path = remote_path
        @nfs.mountpoint = mount_path
        @nfs.fs_type = Y2Storage::Filesystems::Type::NFS
        @nfs.fstopt = mount_options
      end

      # Helper method to decide whether to show the form
      #
      # In case of using a legacy version, the user is asked whether to continue.
      #
      # @return [Boolean]
      def run?
        return true unless nfs.legacy_version?

        edit_legacy?
      end

    private

      # @return [String]
      attr_reader :server

      # @return [String]
      attr_reader :remote_path

      # @return [String]
      attr_reader :mount_path

      # @return [String]
      attr_reader :mount_options

      # @return [Array<Y2Storage::Filesystems::LegacyNfs>]
      attr_reader :nfs_entries

      # Converts the entries to fstab format
      #
      # @return [Array<Hash>]
      def fstab_entries
        nfs_entries.map { |i| storage_to_fstab(i.to_hash) }
      end

      # List of servers
      #
      # @return [Array<String>]
      def servers
        return @servers if @servers

        @servers = [proposed_server].compact
        @servers.concat(nfs_entries.map(&:server).sort)
        @servers.uniq!
        @servers
      end

      # First server to propose
      #
      # It uses the server from the NFS if the given NFS has a server.
      #
      # @return [String]
      def proposed_server
        return nfs.server unless nfs.server && nfs.server.empty?

        proposed = propose_hostname
        return proposed if hostname_exists?(proposed)

        nil
      end

      # Creates mount options from the given options and version, and saves the result
      #
      # @param options [String]
      # @param version [Y2Storage::Filesystems::NfsVersion, nil]
      def set_mount_options(options, version = nil)
        @mount_options = options.strip
        @mount_options = Yast::NfsOptions.set_nfs_version(@mount_options, version) if version
        @mount_options
      end

      # Widget to select the version of the NFS protocol to use in a mount that is being created or
      # edited.
      #
      # @return [NfsVersion]
      def version_widget
        return @version_widget if @version_widget

        initial_version = Yast::NfsOptions.nfs_version(mount_options)

        @version_widget = NfsVersion.new(initial_version)
      end

      # Version of the NFS protocol selected in the corresponding widget
      #
      # @return [Y2Storage::Filesystems::NfsVersion]
      def version_from_widget
        version_widget.value
      end

      # Mount options from the corresponding widget
      #
      # @return [String]
      def mount_options_from_widget
        Yast::UI.QueryWidget(Id(:optionsent), :Value).strip
      end

      # FIXME: Hosts are not correctly found, see bsc#1167589
      def handle_choose
        if @hosts.nil?
          # label message
          Yast::UI.OpenDialog(Label(_("Scanning for hosts on this LAN...")))
          @hosts = Yast::Nfs.ProbeServers
          Yast::UI.CloseDialog
        end
        if @hosts == [] || @hosts.nil?
          # Translators: 1st part of error message
          error_msg = _("No NFS server has been found on your network.")

          if Y2Firewall::Firewalld.instance.running?
            # Translators: 2nd part of error message (1st one is 'No nfs servers have been found ...)
            error_msg += _(
              "\n" \
              "This could be caused by a running firewall,\n" \
              "which probably blocks the network scanning."
            )
          end
          Yast::Report.Error(error_msg)
        else
          host = choose_host_name(@hosts)
          Yast::UI.ChangeWidget(Id(:serverent), :Value, host) if host
        end

        nil
      end

      def handle_pathent_list
        server2 = Yast::UI.QueryWidget(Id(:serverent), :Value)

        if !CheckHostName(server2)
          Yast::UI.SetFocus(Id(:serverent))
          return
        end

        v4 = version_from_widget.need_v4_support?
        scan_exports(server2, v4)

        nil
      end

      def handle_browse
        dir = Yast::UI.QueryWidget(Id(:mountent), :Value)
        dir = "/" if dir.nil? || dir.empty?

        # heading for a directory selection dialog
        dir = Yast::UI.AskForExistingDirectory(dir, _("Select the Mount Point"))

        Yast::UI.ChangeWidget(Id(:mountent), :Value, dir) if dir && !dir.empty?

        nil
      end

      # Allows to select one export from the list of exports
      #
      # @param exports [Array<String>] a list of exports
      # @return [String, nil] nil if nothing was selected
      def choose_export(exports)
        Yast::Wizard.SetScreenShotName("nfs-client-1ab-exports")
        # selection box label
        ret = choose_item(_("&Exported Directories"), exports)
        Yast::Wizard.RestoreScreenShotName
        ret
      end

      # Allows to select one host from the list of hosts
      #
      # @param hosts [Array<String>] a list of hostnames
      # @return [String, nil] nil if nothing was selected
      def choose_host_name(hosts)
        Yast::Wizard.SetScreenShotName("nfs-client-1aa-hosts")
        # selection box label
        # changed from "Remote hosts" because now it shows
        # NFS servers only
        ret = choose_item(_("&NFS Servers"), hosts)
        Yast::Wizard.RestoreScreenShotName
        ret
      end

      # Allows to select one item from a list of items
      #
      # @param title [String] selectionbox title
      # @param items [Array<String>] a list of items
      #
      # @return [String, nil] nil if nothing was selected
      def choose_item(title, items)
        item = nil
        ret = nil

        Yast::UI.OpenDialog(
          VBox(
            HSpacing(40),
            HBox(SelectionBox(Id(:items), title, items), VSpacing(10)),
            ButtonBox(
              PushButton(Id(:ok), Opt(:default, :key_F10), Yast::Label.OKButton),
              PushButton(Id(:cancel), Opt(:key_F9), Yast::Label.CancelButton)
            )
          )
        )
        Yast::UI.SetFocus(Id(:items))
        loop do
          ret = Yast::UI.UserInput
          break if [:ok, :cancel].include?(ret)
        end

        item = Yast::UI.QueryWidget(Id(:items), :CurrentItem) if ret == :ok
        Yast::UI.CloseDialog

        item
      end

      # Scans the server and lets the user to select the export
      #
      # @param server [String] server hostname
      # @param vers4 [Boolen] if true use NFSv4, NFSv3 otherwise
      def scan_exports(server, vers4)
        msg = Yast::Builtins.sformat(_("Getting directory list for \"%1\"..."), server)
        dirs = Yast2::Feedback.show(msg) do
          Yast::Nfs.ProbeExports(server, vers4)
        end

        if dirs
          dir = choose_export(dirs)
          Yast::UI.ChangeWidget(Id(:pathent), :Value, dir) if dir
        else
          # TRANSLATORS: Error message, scanning the NFS server failed
          Yast::Report.Error(_("The NFS scan failed."))
        end
      end

      # Nicely puts a `TextEntry and its helper `PushButton together
      #
      # @param text [Yast::Term] textentry widget
      # @param button [Yast::Term] pushbutton widget
      #
      # @return [Yast::Term]
      def text_and_button(text, button)
        HBox(Bottom(text), HSpacing(0.5), Bottom(button))
      end

      HOST_BIN = "/usr/bin/host".freeze
      private_constant :HOST_BIN

      # Finds out whether this nfs host really exists
      #
      # @param hname [String] hostname
      # @return [Boolean]
      def hostname_exists?(hname)
        ret = false

        if Yast::FileUtils.Exists(HOST_BIN)
          out = Yast::SCR.Execute(
            Yast::Path.new(".target.bash_output"),
            "#{HOST_BIN} #{hname.shellescape}"
          )

          ret = out.fetch("exit", -1) == 0
          log.debug("DNS lookup of #{hname} returned #{ret}")
        else
          log.warn("Cannot DNS lookup #{hname}, will not propose default hostname")
        end

        ret
      end

      # Return convenient hostname (FaTE #302863) to be proposed,
      # i.e. nfs + current domain (nfs. + suse.cz)
      #
      # @return [String]
      def propose_hostname
        ret = ""
        cur_domain = Yast::Hostname.CurrentDomain

        ret = "nfs.#{cur_domain}" if cur_domain && cur_domain != ""
        ret
      end

      # Asks to the user whether to proceed
      #
      # @return [Boolean]
      def edit_legacy?
        msg = _(
          "This entry uses old ways of specifying the NFS protocol version that\n" \
          "do not longer work as they used to do it (like the usage of 'nfs4' as\n" \
          "file system type or the usage of 'minorversion' in the mount options).\n\n" \
          "Editing the entry will change how the version is specified, with no\n" \
          "possibility to use old outdated method again.\n\n" \
          "Proceed and edit?"
        )
        Yast2::Popup.show(msg, buttons: :continue_cancel) == :continue
      end
    end
  end
end
