# Copyright (c) [2013-2020] SUSE LLC
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

require "y2firewall/firewalld"
require "yast2/feedback"
require "yast2/popup"
require "y2nfs_client/nfs_version"

require "shellwords"

# YaST namespace
module Yast
  # NFS client dialogs
  module NfsUiInclude
    def initialize_nfs_ui(include_target)
      Yast.import "UI"
      textdomain "nfs"

      Yast.import "CWMFirewallInterfaces"
      Yast.import "Hostname"
      Yast.import "FileUtils"
      Yast.import "Label"
      Yast.import "Nfs"
      Yast.import "NfsOptions"
      Yast.import "Popup"
      Yast.import "Wizard"
      Yast.import "Report"
      Yast.include include_target, "nfs/routines.rb"

      # Caches names of nfs servers for GetFstabEntry

      @hosts = nil

      # List of already defined nfs mount points
      @nfs_entries = deep_copy(Nfs.nfs_entries)

      # firewall widget using CWM
      @fw_settings = {
        "services"        => ["nfs"],
        "display_details" => true
      }
      @fw_cwm_widget = CWMFirewallInterfaces.CreateOpenFirewallWidget(
        @fw_settings
      )

      @modify_line = {}

      # Help, part 1 of 4
      @help_text1 = _(
        "<p>The table contains all directories \n" \
          "exported from remote servers and mounted locally via NFS (NFS shares).</p>"
      ) +
        # Help, part 2 of 4
        _(
          "<p>Each NFS share is identified by remote NFS server address and\n" \
          "exported directory, local directory where the remote directory is mounted, \n" \
          "version of the NFS protocol and mount options. For further information \n" \
          "about mounting NFS and mount options, refer to <tt>man nfs</tt>.</p>\n" \
          "<p>An asterisk (*) after the mount point indicates a file system that is \n" \
          "currently not mounted (for example, because it has the <tt>noauto</tt> \n" \
          "option set in <tt>/etc/fstab</tt>).</p>"
        ) +
        # Help, part 3 of 4
        _(
          "<p>It may happen that some NFS share is mounted using an old method\n" \
            "to specify the version of the NFS protocol, like the usage of 'nfs4'\n" \
            "as file system type or the usage of 'minorversion' in the mount options.\n" \
            "Those methods do not longer work as they used to, so if such\n" \
            "circumstance is detected, the real current version is displayed in the\n" \
            "list followed by a warning message. Those entries can be edited to\n" \
            "make sure they use more current ways of specifying the version.</p>"
        ) +
        # Help, part 4 of 4
        _(
          "<p>To mount a new NFS share, click <B>Add</B>. To change the configuration of\n" \
            "a currently mounted share, click <B>Edit</B>. Remove and unmount a selected\n" \
            "share with <B>Delete</B>.</p>\n"
        )

      @help_text2 = Ops.add(
        _(
          "<p>If you need to access NFSv4 shares (NFSv4 is a newer version of the NFS\n" \
            "protocol), check the <b>NFS version</b> option. In that case, you might need\n" \
            "to supply an specific <b>NFSv4 Domain Name</b> required for the correct setting\n" \
            "of file/directory access rights.</p>\n"
        ),
        Ops.get_string(@fw_cwm_widget, "help", "")
      )
    end

    # Read settings dialog
    # @return `abort if aborted and `next otherwise
    def ReadDialog
      ret = Nfs.Read
      ret ? :next : :abort
    end

    # Write settings dialog
    # @return `abort if aborted and `next otherwise
    def WriteDialog
      ret = Nfs.Write
      ret ? :next : :abort
    end

    # Let the user choose one of a list of items
    # @param [String] title	selectionbox title
    # @param [Array<String>] items	a list of items
    # @return		one item or nil
    def ChooseItem(title, items)
      items = deep_copy(items)
      item = nil
      ret = nil

      UI.OpenDialog(
        VBox(
          HSpacing(40),
          HBox(SelectionBox(Id(:items), title, items), VSpacing(10)),
          ButtonBox(
            PushButton(Id(:ok), Opt(:default, :key_F10), Label.OKButton),
            PushButton(Id(:cancel), Opt(:key_F9), Label.CancelButton)
          )
        )
      )
      UI.SetFocus(Id(:items))
      loop do
        ret = UI.UserInput
        break if ret == :ok || ret == :cancel
      end

      if ret == :ok
        item = Convert.to_string(UI.QueryWidget(Id(:items), :CurrentItem))
      end
      UI.CloseDialog

      item
    end

    HOST_BIN = "/usr/bin/host".freeze
    # Find out whether this nfs host really exists
    # @param [String] hname	hostname
    # @return true if it exists, false otherwise
    def HostnameExists(hname)
      ret = false

      if FileUtils.Exists(HOST_BIN)
        out = SCR.Execute(
          path(".target.bash_output"),
          "#{HOST_BIN} #{hname.shellescape}"
        )

        ret = Ops.get_integer(out, "exit", -1) == 0
        Builtins.y2debug("DNS lookup of %1 returned %2", hname, ret)
      else
        Builtins.y2warning(
          "Cannot DNS lookup %1, will not propose default hostname",
          hname
        )
      end

      ret
    end

    # Return convenient hostname (FaTE #302863) to be proposed
    # i.e. nfs + current domain (nfs. + suse.cz)
    # @return string	proposed hostname
    def ProposeHostname
      ret = ""
      cur_domain = Hostname.CurrentDomain

      ret = "nfs.#{cur_domain}" if cur_domain && cur_domain != ""
      ret
    end

    # Give me one name from the list of hosts
    # @param [Array<String>] hosts	a list of hostnames
    # @return		a hostname
    def ChooseHostName(hosts)
      hosts = deep_copy(hosts)
      Wizard.SetScreenShotName("nfs-client-1aa-hosts")
      # selection box label
      # changed from "Remote hosts" because now it shows
      # NFS servers only
      ret = ChooseItem(_("&NFS Servers"), hosts)
      Wizard.RestoreScreenShotName
      ret
    end

    # Give me one name from the list of exports
    # @param [Array<String>] exports	a list of exports
    # @return		an export
    def ChooseExport(exports)
      exports = deep_copy(exports)
      Wizard.SetScreenShotName("nfs-client-1ab-exports")
      # selection box label
      ret = ChooseItem(_("&Exported Directories"), exports)
      Wizard.RestoreScreenShotName
      ret
    end

    # Nicely put a `TextEntry and its helper `PushButton together
    # @param [Yast::Term] text   textentry widget
    # @param [Yast::Term] button pushbutton widget
    # @return a HBox
    def TextAndButton(text, button)
      text = deep_copy(text)
      button = deep_copy(button)
      HBox(Bottom(text), HSpacing(0.5), Bottom(button))
    end

    # Ask user for an entry.
    # @param [Hash{String => Object}] fstab_ent	$["spec": "file": "mntops":] or nil
    # @param [Array<Hash>] existing	list of fstab entries for duplicate mount-point checking
    # @return		a nfs_entry or nil
    def GetFstabEntry(fstab_ent, existing)
      fstab_ent = deep_copy(fstab_ent)
      Wizard.SetScreenShotName("nfs-client-1a-edit")

      server = ""
      pth = ""
      mount = ""
      options = "defaults"
      servers = []
      old = ""
      ret = nil

      if fstab_ent
        new_entry = fstab_ent.fetch("new", false)

        couple = SpecToServPath(Ops.get_string(fstab_ent, "spec", ""))
        server = Ops.get_string(couple, 0, "")
        pth = Ops.get_string(couple, 1, "")
        mount = Ops.get_string(fstab_ent, "file", "")
        options = Ops.get_string(fstab_ent, "mntops", "")
        servers = [server]
        old = Ops.get_string(fstab_ent, "spec", "")
      else
        new_entry = true

        proposed_server = ProposeHostname()
        servers = [proposed_server] if HostnameExists(proposed_server)
      end
      version = NfsOptions.nfs_version(options)

      # append already defined servers - bug #547983
      Builtins.foreach(@nfs_entries) do |nfs_entry|
        couple = SpecToServPath(Ops.get_string(nfs_entry, "spec", ""))
        known_server = Ops.get_string(couple, 0, "")
        if !Builtins.contains(servers, known_server)
          servers = Builtins.add(servers, known_server)
        end
      end

      servers = Builtins.sort(servers)
      #

      UI.OpenDialog(
        Opt(:decorated),
        HBox(
          HSpacing(1),
          VBox(
            VSpacing(0.2),
            HBox(
              TextAndButton(
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
              TextAndButton(
                InputField(
                  Id(:pathent),
                  Opt(:hstretch),
                  # textentry label
                  _("&Remote Directory"),
                  pth
                ),
                # pushbutton label,
                # select from a list of remote filesystems
                # make it short
                # appears in help text too
                PushButton(Id(:pathent_list), _("&Select"))
              )
            ),
            Left(
              version_widget(version)
            ),
            Left(
              TextAndButton(
                InputField(
                  Id(:mountent),
                  Opt(:hstretch),
                  # textentry label
                  _("&Mount Point (local)"),
                  mount
                ),
                # button label
                # browse directories to select a mount point
                # appears in help text too
                PushButton(Id(:browse), _("&Browse"))
              )
            ),
            # textentry label
            VSpacing(0.2),
            InputField(Id(:optionsent), Opt(:hstretch), _("O&ptions"), options),
            VSpacing(0.2),
            ButtonBox(
              PushButton(Id(:ok), Opt(:default, :key_F10), Label.OKButton),
              PushButton(Id(:cancel), Opt(:key_F9), Label.CancelButton),
              PushButton(Id(:help), Opt(:key_F1), Label.HelpButton)
            ),
            VSpacing(0.2)
          ),
          HSpacing(1)
        )
      )
      UI.ChangeWidget(Id(:serverent), :Value, server)
      UI.SetFocus(Id(:serverent))

      loop do
        ret = UI.UserInput

        if ret == :choose
          if @hosts.nil?
            # label message
            UI.OpenDialog(Label(_("Scanning for hosts on this LAN...")))
            @hosts = Nfs.ProbeServers
            UI.CloseDialog
          end
          if @hosts == [] || @hosts.nil?
            # Translators: 1st part of error message
            error_msg = _("No NFS server has been found on your network.")

            if Y2Firewall::Firewalld.instance.running?
              # Translators: 2nd part of error message (1st one is 'No nfs servers have been found ...)
              error_msg = Ops.add(
                error_msg,
                _(
                  "\n" \
                    "This could be caused by a running firewall,\n" \
                    "which probably blocks the network scanning."
                )
              )
            end
            Report.Error(error_msg)
          else
            host = ChooseHostName(@hosts)
            UI.ChangeWidget(Id(:serverent), :Value, host) if host
          end
        elsif ret == :pathent_list
          server2 = UI.QueryWidget(Id(:serverent), :Value)

          if !CheckHostName(server2)
            UI.SetFocus(Id(:serverent))
            next
          end

          v4 = version_from_widget.browse_with_v4?
          scan_exports(server2, v4)
        elsif ret == :browse
          dir = Convert.to_string(UI.QueryWidget(Id(:mountent), :Value))
          dir = "/" if dir.nil? || Builtins.size(dir) == 0

          # heading for a directory selection dialog
          dir = UI.AskForExistingDirectory(dir, _("Select the Mount Point"))

          if dir && Ops.greater_than(Builtins.size(dir), 0)
            UI.ChangeWidget(Id(:mountent), :Value, dir)
          end
        elsif ret == :ok
          server = FormatHostnameForFstab(
            Convert.to_string(UI.QueryWidget(Id(:serverent), :Value))
          )
          pth = StripExtraSlash(
            Convert.to_string(UI.QueryWidget(Id(:pathent), :Value))
          )
          mount = StripExtraSlash(
            Convert.to_string(UI.QueryWidget(Id(:mountent), :Value))
          )
          options = Builtins.deletechars(
            Convert.to_string(UI.QueryWidget(Id(:optionsent), :Value)),
            " "
          )
          options = NfsOptions.set_nfs_version(options, version_from_widget)

          ret = nil
          options_error = NfsOptions.validate(options)
          if !CheckHostName(server)
            UI.SetFocus(Id(:serverent))
          elsif !CheckPath(pth)
            UI.SetFocus(Id(:pathent))
          elsif !CheckPath(mount) || IsMpInFstab(existing, mount)
            UI.SetFocus(Id(:mountent))
          elsif Ops.greater_than(Builtins.size(options_error), 0)
            Popup.Error(options_error)
            UI.SetFocus(Id(:optionsent))
          else
            fstab_ent = {
              "spec"    => Ops.add(Ops.add(server, ":"), pth),
              "file"    => mount,
              "vfstype" => "nfs",
              "mntops"  => options
            }
            if old != Ops.add(Ops.add(server, ":"), pth)
              fstab_ent = Builtins.add(fstab_ent, "old", old)
            end
            ret = :ok
          end
        elsif ret == :help
          # help text 1/4
          # change: locally defined -> servers on LAN
          helptext = _(
            "<p>Enter the <b>NFS Server Hostname</b>.  With\n" \
              "<b>Choose</b>, browse through a list of\n" \
              "NFS servers on the local network.</p>\n"
          )
          # help text 2/4
          # added "Select" button
          helptext = Ops.add(
            helptext,
            _(
              "<p>In <b>Remote File System</b>,\n" \
                "enter the path to the directory on the NFS server.  Use\n" \
                "<b>Select</b> to select one from those exported by the server.\n" \
                "</p>"
            )
          )
          # help text 3/4
          helptext = Ops.add(
            helptext,
            _(
              "<p>\t\t\n" \
                "For <b>Mount Point</b>, enter the path in the local " \
                "file system where the directory should be mounted. With\n" \
                "<b>Browse</b>, select your mount point\n" \
                "interactively.</p>"
            )
          )
          # help text 4/4
          helptext = Ops.add(
            helptext,
            _(
              "<p>For a list of <b>Options</b>,\nread the man page mount(8).</p>"
            )
          )
          # popup heading
          Popup.LongText(_("Help"), RichText(helptext), 50, 18)
        end
        break if ret == :ok || ret == :cancel
      end

      UI.CloseDialog
      Wizard.RestoreScreenShotName

      # New entries are identify by "new" key in the hash. This is useful to detect which entries are
      # not created but updated. Note that this is important to keep the current mount point status of
      # updated entries.
      fstab_ent["new"] = new_entry

      return deep_copy(fstab_ent) if ret == :ok
      nil
    end

    def EnableDisableButtons
      UI.ChangeWidget(Id(:editbut), :Enabled, @nfs_entries != [])
      UI.ChangeWidget(Id(:delbut), :Enabled, @nfs_entries != [])

      nil
    end

    def FstabTab
      fstab_content = VBox(
        Table(
          Id(:fstable),
          Opt(:notify, :immediate),
          Header(
            # table header
            _("Server") + "  ",
            _("Remote Directory") + "  ",
            # table header
            _("Mount Point") + "  ",
            # table header
            _("NFS Version"),
            # table header
            _("Options") + "  "
          ),
          FstabTableItems(@nfs_entries)
        ),
        HBox(
          PushButton(Id(:newbut), Opt(:key_F3), Label.AddButton),
          PushButton(Id(:editbut), Opt(:key_F4), Label.EditButton),
          PushButton(Id(:delbut), Opt(:key_F5), Label.DeleteButton),
          # #211570
          HStretch()
        )
      )

      deep_copy(fstab_content)
    end

    def SettingsTab
      settings_content = VBox(
        HBox(
          Left(CheckBox(Id(:enable_nfs4), Opt(:notify), _("Enable NFSv4"))),
          Left(InputField(Id(:nfs4_domain), _("NFSv4 Domain Name"))),
          HStretch()
        ),
        VSpacing(1),
        Left(
          CheckBox(Id(:enable_nfs_gss), Opt(:notify), _("Enable &GSS Security"))
        ),
        VSpacing(1),
        Ops.get_term(@fw_cwm_widget, "custom_widget", Empty()),
        VStretch()
      )

      deep_copy(settings_content)
    end

    def MainDialogLayout
      contents = VBox(
        DumbTab(
          [
            Item(Id(:overview), _("&NFS Shares")),
            Item(Id(:settings), _("NFS &Settings"))
          ],
          ReplacePoint(Id(:rp), FstabTab())
        )
      )

      deep_copy(contents)
    end

    def InitFstabEntries
      UI.ChangeWidget(Id(:fstable), :Items, FstabTableItems(@nfs_entries))
      EnableDisableButtons()

      nil
    end

    def InitSettings
      CWMFirewallInterfaces.OpenFirewallInit(@fw_cwm_widget, "")
      UI.ChangeWidget(Id(:enable_nfs4), :Value, Nfs.nfs4_enabled != false)
      UI.ChangeWidget(Id(:nfs4_domain), :Enabled, Nfs.nfs4_enabled != false)
      UI.ChangeWidget(Id(:nfs4_domain), :Value, Nfs.idmapd_domain)
      UI.ChangeWidget(Id(:enable_nfs_gss), :Value, Nfs.nfs_gss_enabled != false)

      nil
    end

    def SaveFstabEntries
      Nfs.nfs_entries = deep_copy(@nfs_entries)

      nil
    end

    def SaveSettings(event)
      event = deep_copy(event)
      CWMFirewallInterfaces.OpenFirewallStore(@fw_cwm_widget, "", event)
      Nfs.nfs4_enabled = Convert.to_boolean(
        UI.QueryWidget(Id(:enable_nfs4), :Value)
      )
      Nfs.nfs_gss_enabled = Convert.to_boolean(
        UI.QueryWidget(Id(:enable_nfs_gss), :Value)
      )
      Nfs.idmapd_domain = Convert.to_string(
        UI.QueryWidget(Id(:nfs4_domain), :Value)
      )

      nil
    end

    def HandleEvent(widget)
      widget = deep_copy(widget)
      entryno = -1
      # handle the events, enable/disable the button, show the popup if button clicked
      if UI.WidgetExists(Id("_cwm_firewall_details")) &&
          UI.WidgetExists(Id("_cwm_open_firewall"))
        CWMFirewallInterfaces.OpenFirewallHandle(
          @fw_cwm_widget,
          "",
          "ID" => widget
        )
      end
      if UI.WidgetExists(Id(:fstable))
        entryno = Convert.to_integer(UI.QueryWidget(Id(:fstable), :CurrentItem))
      end

      if widget == :newbut
        entry = GetFstabEntry(nil, @nfs_entries)

        if entry
          @nfs_entries = Builtins.add(@nfs_entries, entry)
          @modify_line = deep_copy(entry)
          EnableDisableButtons()

          Nfs.SetModified
        end

        UI.ChangeWidget(Id(:fstable), :Items, FstabTableItems(@nfs_entries))
      elsif widget == :editbut
        # Handle situations in which edit is called with no entry selected
        # (caused by a bug in yast2-storage-ng)
        return EnableDisableButtons() if entryno.nil?

        source_entry = @nfs_entries[entryno] || {}
        if !legacy_entry?(source_entry) || edit_legacy?
          edit_entry(source_entry, entryno)
        end
      elsif widget == :delbut
        # Handle unexpected delete request. The delete button shouldn't be
        # enabled if there are no entries, but it can happen due to a bug
        # in yast2-storage-ng
        return EnableDisableButtons() if @nfs_entries.empty? || entryno.nil?

        share = Ops.get(@nfs_entries, entryno, {})
        if Popup.YesNo(
          Builtins.sformat(
            _("Really delete %1?"),
            Ops.get_string(share, "spec", "")
          )
        )
          @modify_line = deep_copy(share)
          @nfs_entries = Builtins.remove(@nfs_entries, entryno)
          UI.ChangeWidget(Id(:fstable), :Items, FstabTableItems(@nfs_entries))
          EnableDisableButtons()

          Nfs.SetModified
        end
      elsif widget == :enable_nfs4
        enabled = Convert.to_boolean(UI.QueryWidget(Id(:enable_nfs4), :Value))
        UI.ChangeWidget(Id(:nfs4_domain), :Enabled, enabled)
        Nfs.SetModified
      elsif widget == :settings
        SaveFstabEntries()
        UI.ReplaceWidget(Id(:rp), SettingsTab())
        InitSettings()
        Wizard.SetHelpText(@help_text2)
      elsif widget == :overview
        SaveSettings("ID" => widget)
        UI.ReplaceWidget(Id(:rp), FstabTab())
        InitFstabEntries()
        Wizard.SetHelpText(@help_text1)
      end

      nil
    end

    # NFS client dialog itselfs
    # @return `back, `abort or `next
    def FstabDialog
      ret = nil
      event = nil
      Wizard.SetScreenShotName("nfs-client-1-fstab")

      @nfs_entries = deep_copy(Nfs.nfs_entries)

      # dialog heading
      Wizard.SetContents(
        _("NFS Client Configuration"),
        MainDialogLayout(),
        @help_text1,
        false,
        true
      )

      InitFstabEntries()

      # Kludge, because a `Table still does not have a shortcut.
      # Simple to solve here: there's only the table and buttons,
      # so it is OK to always set focus to the table
      UI.SetFocus(Id(:fstable))

      loop do
        event = UI.WaitForEvent
        ret = Ops.get(event, "ID")
        if ret == :ok
          ret = :next
        elsif ret == :cancel
          ret = :abort
        elsif ret == :abort && Nfs.GetModified && !Popup.ReallyAbort(true)
          ret = :again
        else
          HandleEvent(ret)
        end
        break if [:back, :next, :abort].include? ret
      end

      if ret == :next
        # grab current settings, store them to firewalld::
        SaveFstabEntries() if UI.WidgetExists(Id(:fstable))
        SaveSettings(event) if UI.WidgetExists(Id(:enable_nfs4))
      end

      Wizard.RestoreScreenShotName
      Convert.to_symbol(ret)
    end

    # Scans the server and lets the user to select the export
    # @param server [String] server hostname
    # @param v4 [Boolen] if true use NFSv4, NFSv3 otherwise
    def scan_exports(server, v4)
      msg = Builtins.sformat(_("Getting directory list for \"%1\"..."), server)
      dirs = Yast2::Feedback.show(msg) do
        Nfs.ProbeExports(server, v4)
      end

      if dirs
        dir = ChooseExport(dirs)
        UI.ChangeWidget(Id(:pathent), :Value, dir) if dir
      else
        # TRANSLATORS: Error message, scanning the NFS server failed
        Report.Error(_("The NFS scan failed."))
      end
    end

  private

    # Widget to select the version of the NFS protocol to use in a mount that is
    # being created or edited.
    def version_widget(current_version)
      items = Y2NfsClient::NfsVersion.all.map do |vers|
        Item(Id(vers.widget_id), vers.widget_text, current_version == vers)
      end
      ComboBox(Id(:nfs_version), _("NFS &Version"), items)
    end

    # Version of the NFS protocol selected in the corresponding widget.
    #
    # @return [Y2NfsClient::NfsVersion]
    def version_from_widget
      id = UI.QueryWidget(Id(:nfs_version), :Value).to_sym
      Y2NfsClient::NfsVersion.all.find { |v| v.widget_id == id }
    end

    # @see #HandleEvent
    def edit_entry(source_entry, entryno)
      entry = GetFstabEntry(source_entry, Builtins.remove(@nfs_entries, entryno))

      if entry
        count2 = 0
        @nfs_entries = Builtins.maplist(@nfs_entries) do |ent|
          count2 = Ops.add(count2, 1)
          next deep_copy(ent) if Ops.subtract(count2, 1) != entryno
          deep_copy(entry)
        end

        @modify_line = deep_copy(entry)
        UI.ChangeWidget(Id(:fstable), :Items, FstabTableItems(@nfs_entries))
        Nfs.SetModified
      end
    end

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
