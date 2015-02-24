# encoding: utf-8

require "nfs_client/fstab_entry_dialog"

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
      Yast.import "SuSEFirewall"
      Yast.import "Wizard"
      Yast.include include_target, "nfs/routines.rb"

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
      ret = Nfs.Read
      ret ? :next : :abort
    end

    # Write settings dialog
    # @return `abort if aborted and `next otherwise
    def WriteDialog
      ret = Nfs.Write
      ret ? :next : :abort
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
        entry = ::NfsClient::FstabEntryDialog.new(
          nil,
          Convert.convert(
            Builtins.union(Nfs.non_nfs_entries, @nfs_entries),
            :from => "list",
            :to   => "list <map>"
          ),
          @nfs_entries
        ).run

        if entry
          @nfs_entries = Builtins.add(@nfs_entries, entry)
          @modify_line = deep_copy(entry)
          EnableDisableButtons()

          Nfs.SetModified
        end

        UI.ChangeWidget(Id(:fstable), :Items, FstabTableItems(@nfs_entries))
      elsif widget == :editbut
        entry = ::NfsClient::FstabEntryDialog.new(
          Ops.get(@nfs_entries, entryno, {}),
          Convert.convert(
            Builtins.union(
              Nfs.non_nfs_entries,
              Builtins.remove(@nfs_entries, entryno)
            ),
            :from => "list",
            :to   => "list <map>"
          ), # Default values
          @nfs_entries
        ).run
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
        # grab current settings, store them to SuSEFirewall::
        SaveFstabEntries() if UI.WidgetExists(Id(:fstable))
        SaveSettings(event) if UI.WidgetExists(Id(:enable_nfs4))
      end

      Wizard.RestoreScreenShotName
      Convert.to_symbol(ret)
    end
  end
end
