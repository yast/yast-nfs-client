# encoding: utf-8

# File:
#   ui.ycp
#
# Module:
#   Configuration of nfs
#
# Summary:
#   Network NFS client dialogs
#
# Authors:
#   Jan Holesovsky <kendy@suse.cz>
#   Dan Vesely <dan@suse.cz>
#   Martin Vidner <mvidner@suse.cz>
#
# $Id$
#
# Network NFS client dialogs
#
module Yast
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
      Yast.import "SuSEFirewall"
      Yast.import "Wizard"
      Yast.include include_target, "nfs/routines.rb"

      # Caches names of nfs servers for GetFstabEntry

      @hosts = nil

      # List of already defined nfs mount points
      @nfs_entries = deep_copy(Nfs.nfs_entries)

      # firewall widget using CWM
      @fw_settings = {
        "services"        => ["service:nfs-client"],
        "display_details" => true
      }
      @fw_cwm_widget = CWMFirewallInterfaces.CreateOpenFirewallWidget(
        @fw_settings
      )

      @modify_line = {}

      # Help, part 1 of 3
      @help_text1 = _(
        "<p>The table contains all directories \n" \
          "exported from remote servers and mounted locally via NFS (NFS shares).</p>"
      ) +
        # Help, part 2 of 3
        _(
          "<p>Each NFS share is identified by remote NFS server address and\n" \
            "exported directory, local directory where the remote directory is mounted, \n" \
            "NFS type (either plain nfs or nfsv4) and mount options. For further information \n" \
            "about mounting NFS and mount options, refer to <tt>man nfs.</tt></p>"
        ) +
        # Help, part 3 of 3
        _(
          "<p>To mount a new NFS share, click <B>Add</B>. To change the configuration of\n" \
            "a currently mounted share, click <B>Edit</B>. Remove and unmount a selected\n" \
            "share with <B>Delete</B>.</p>\n"
        )


      @help_text2 = Ops.add(
        _(
          "<p>If you need to access NFSv4 shares (NFSv4 is a newer version of the NFS\n" \
            "protocol), check the <b>Enable NFSv4</b> option. In that case, you might need\n" \
            "to supply specific a <b>NFSv4 Domain Name</b> required for the correct setting\n" \
            "of file/directory access rights.</p>\n"
        ),
        Ops.get_string(@fw_cwm_widget, "help", "")
      )
    end

    # Read settings dialog
    # @return `abort if aborted and `next otherwise
    def ReadDialog
      ret = nil
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
      ret = nil
      begin
        ret = UI.UserInput
      end while ret != :cancel && ret != :ok

      if ret == :ok
        item = Convert.to_string(UI.QueryWidget(Id(:items), :CurrentItem))
      end
      UI.CloseDialog

      item
    end

    # Find out whether this nfs host really exists
    # @param [String] hname	hostname
    # @return true if it exists, false otherwise
    def HostnameExists(hname)
      prog_name = "/usr/bin/host"
      ret = false

      if FileUtils.Exists(prog_name)
        out = Convert.to_map(
          SCR.Execute(
            path(".target.bash_output"),
            Builtins.sformat("%1 %2", prog_name, hname)
          )
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

      ret = Ops.add("nfs.", cur_domain) if cur_domain != nil || cur_domain != ""
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
      existing = deep_copy(existing)
      Wizard.SetScreenShotName("nfs-client-1a-edit")

      server = ""
      pth = ""
      mount = ""
      nfs4 = false
      nfs41 = false
      options = "defaults"
      servers = []
      old = ""

      if fstab_ent != nil
        couple = SpecToServPath(Ops.get_string(fstab_ent, "spec", ""))
        server = Ops.get_string(couple, 0, "")
        pth = Ops.get_string(couple, 1, "")
        mount = Ops.get_string(fstab_ent, "file", "")
        nfs4 = Ops.get_string(fstab_ent, "vfstype", "") == "nfs4"
        options = Ops.get_string(fstab_ent, "mntops", "")
        nfs41 = nfs4 && NfsOptions.get_nfs41(options)
        servers = [server]
        old = Ops.get_string(fstab_ent, "spec", "")
      else
        proposed_server = ProposeHostname()
        servers = [proposed_server] if HostnameExists(proposed_server)
      end

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
              HBox(
                CheckBox(Id(:nfs4), _("NFS&v4 Share"), nfs4),
                HSpacing(2),
                # parallel NFS, protocol version 4.1
                CheckBox(Id(:nfs41), _("pNFS (v4.1)"), nfs41)
              )
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

      ret = nil
      begin
        ret = UI.UserInput

        if ret == :choose
          if @hosts == nil
            # label message
            UI.OpenDialog(Label(_("Scanning for hosts on this LAN...")))
            @hosts = Nfs.ProbeServers
            UI.CloseDialog
          end
          if @hosts == [] || @hosts == nil
            #Translators: 1st part of error message
            error_msg = _("No NFS server has been found on your network.")

            if SuSEFirewall.GetStartService
              #Translators: 2nd part of error message (1st one is 'No nfs servers have been found ...)
              error_msg = Ops.add(
                error_msg,
                _(
                  "\n" \
                    "This could be caused by a running SuSEfirewall2,\n" \
                    "which probably blocks the network scanning."
                )
              )
            end
            Report.Error(error_msg)
          else
            host = ChooseHostName(@hosts)
            UI.ChangeWidget(Id(:serverent), :Value, host) if host != nil
          end
        elsif ret == :pathent_list
          server2 = Convert.to_string(UI.QueryWidget(Id(:serverent), :Value))
          v4 = Convert.to_boolean(UI.QueryWidget(Id(:nfs4), :Value))

          if !CheckHostName(server2)
            UI.SetFocus(Id(:serverent))
            next
          end

          UI.OpenDialog(
            Label(
              # Popup dialog, %1 is a host name
              Builtins.sformat(
                _("Getting directory list for \"%1\"..."),
                server2
              )
            )
          )
          dirs = Nfs.ProbeExports(server2, v4)
          UI.CloseDialog

          dir = ChooseExport(dirs)
          UI.ChangeWidget(Id(:pathent), :Value, dir) if dir != nil
        elsif ret == :browse
          dir = Convert.to_string(UI.QueryWidget(Id(:mountent), :Value))
          dir = "/" if dir == nil || Builtins.size(dir) == 0

          # heading for a directory selection dialog
          dir = UI.AskForExistingDirectory(dir, _("Select the Mount Point"))

          if dir != nil && Ops.greater_than(Builtins.size(dir), 0)
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
          nfs4 = Convert.to_boolean(UI.QueryWidget(Id(:nfs4), :Value))
          nfs41 = Convert.to_boolean(UI.QueryWidget(Id(:nfs41), :Value))
          options = Builtins.deletechars(
            Convert.to_string(UI.QueryWidget(Id(:optionsent), :Value)),
            " "
          )
          options = NfsOptions.set_nfs41(options, nfs41)

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
              "vfstype" => nfs4 ? "nfs4" : "nfs",
              "mntops"  => options
            }
            if old != Ops.add(Ops.add(server, ":"), pth)
              fstab_ent = Builtins.add(fstab_ent, "old", old)
            end
            ret = :ok
          end
        elsif ret == :help
          #help text 1/4
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
              "<p>\t\t\n" +
                "For <b>Mount Point</b>, enter the path in the local " \
                "file system where the directory should be mounted. With\n" +
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
      end while ret != :ok && ret != :cancel

      UI.CloseDialog
      Wizard.RestoreScreenShotName

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
            _("NFS Type"),
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
        #`VSpacing (1),
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
          { "ID" => widget }
        )
      end
      if UI.WidgetExists(Id(:fstable))
        entryno = Convert.to_integer(UI.QueryWidget(Id(:fstable), :CurrentItem))
      end

      if widget == :newbut
        entry = GetFstabEntry(
          nil,
          Convert.convert(
            Builtins.union(Nfs.non_nfs_entries, @nfs_entries),
            :from => "list",
            :to   => "list <map>"
          )
        )

        if entry != nil
          @nfs_entries = Builtins.add(@nfs_entries, entry)
          @modify_line = deep_copy(entry)
          EnableDisableButtons()

          Nfs.SetModified
        end

        UI.ChangeWidget(Id(:fstable), :Items, FstabTableItems(@nfs_entries))
      elsif widget == :editbut
        count = 0
        entry = GetFstabEntry(
          Ops.get(@nfs_entries, entryno, {}),
          Convert.convert(
            Builtins.union(
              Nfs.non_nfs_entries,
              Builtins.remove(@nfs_entries, entryno)
            ),
            :from => "list",
            :to   => "list <map>"
          ) # Default values
        )
        if entry != nil
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
      elsif widget == :delbut &&
          Ops.greater_than(Builtins.size(@nfs_entries), 0)
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
        SaveSettings({ "ID" => widget })
        UI.ReplaceWidget(Id(:rp), FstabTab())
        InitFstabEntries()
        Wizard.SetHelpText(@help_text1)
      end

      nil
    end

    # NFS client dialog itselfs
    # @return `back, `abort or `next
    def FstabDialog
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
      #Wizard::HideBackButton();
      #Wizard::SetAbortButton(`abort, Label::CancelButton());

      InitFstabEntries()

      # Kludge, because a `Table still does not have a shortcut.
      # Simple to solve here: there's only the table and buttons,
      # so it is OK to always set focus to the table
      UI.SetFocus(Id(:fstable))

      event = nil
      ret = nil
      entryno = -1
      begin
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
      end while ret != :back && ret != :next && ret != :abort

      if ret == :next
        # grab current settings, store them to SuSEFirewall::
        SaveFstabEntries() if UI.WidgetExists(Id(:fstable))
        SaveSettings(event) if UI.WidgetExists(Id(:enable_nfs4))
      end

      Wizard.RestoreScreenShotName
      Convert.to_symbol(ret)
    end
  end
end
