# Copyright (c) [2013-2022] SUSE LLC
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
require "y2nfs_client/widgets/nfs_form"
require "y2partitioner/widgets/help"

require "shellwords"

# YaST namespace
module Yast
  # NFS client dialogs
  module NfsUiInclude
    include Y2Partitioner::Widgets::Help

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

      @help_text1 =
        _("<p>The table contains all directories \n" \
          "exported from remote servers and mounted locally via NFS (NFS shares).</p>") +
        _("<p>Each NFS share is identified by remote NFS server address and\n" \
          "exported directory, local directory where the remote directory is mounted, \n" \
          "version of the NFS protocol and mount options. For further information \n" \
          "about mounting NFS and mount options, refer to <tt>man nfs</tt>.</p>") +
        helptext_for(:mount_point) + helptext_for(:nfs_version) +
        _("<p>To mount a new NFS share, click <B>Add</B>. To change the configuration of\n" \
          "a currently mounted share, click <B>Edit</B>. Remove and unmount a selected\n" \
          "share with <B>Delete</B>.</p>")

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

    def devicegraph
      Y2Storage::StorageManager.instance.staging
    end

    # Ask user for an entry.
    # @param [Hash{String => Object}] fstab_ent	$["spec": "file": "mntops":] or nil
    # @param [Array<Hash>] existing	list of fstab entries for duplicate mount-point checking
    # @return		a nfs_entry or nil
    def GetFstabEntry(fstab_ent, existing)
      fstab_ent = deep_copy(fstab_ent)
      Wizard.SetScreenShotName("nfs-client-1a-edit")

      ret = nil

      nfs_entries = existing.map { |i| to_legacy_nfs(i) }
      nfs = nil
      if fstab_ent
        nfs = to_legacy_nfs(fstab_ent)
      else
        nfs = Y2Storage::Filesystems::LegacyNfs.new
        nfs.fstopt = "defaults"
      end

      form = Y2NfsClient::Widgets::NfsForm.new(nfs, nfs_entries, hosts: @hosts)
      return nil unless form.run?

      UI.OpenDialog(
        Opt(:decorated),
        HBox(
          HSpacing(1),
          VBox(
            form.contents,
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

      form.init

      loop do
        ret = UI.UserInput

        case ret
        when :ok
          if form.validate
            form.store
          else
            ret = nil
          end
        when :help
          helptext = form.help
          # popup heading
          Popup.LongText(_("Help"), RichText(helptext), 50, 18)
        else
          form.handle({ "ID" => ret })
        end
        break if [:ok, :cancel].include?(ret)
      end

      @hosts = form.hosts

      UI.CloseDialog
      Wizard.RestoreScreenShotName

      return nil if ret == :cancel

      fstab_ent = storage_to_fstab(form.nfs.to_hash)
      return fstab_ent if ret == :ok

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
      entryno = Convert.to_integer(UI.QueryWidget(Id(:fstable), :CurrentItem)) if UI.WidgetExists(Id(:fstable))

      case widget
      when :newbut
        entry = GetFstabEntry(nil, @nfs_entries)

        if entry
          @nfs_entries = Builtins.add(@nfs_entries, entry)
          @modify_line = deep_copy(entry)
          EnableDisableButtons()

          Nfs.SetModified
        end

        UI.ChangeWidget(Id(:fstable), :Items, FstabTableItems(@nfs_entries))
      when :editbut
        source_entry = @nfs_entries[entryno] || {}
        edit_entry(source_entry, entryno)
      when :delbut
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
      when :enable_nfs4
        enabled = Convert.to_boolean(UI.QueryWidget(Id(:enable_nfs4), :Value))
        UI.ChangeWidget(Id(:nfs4_domain), :Enabled, enabled)
        Nfs.SetModified
      when :settings
        SaveFstabEntries()
        UI.ReplaceWidget(Id(:rp), SettingsTab())
        InitSettings()
        Wizard.SetHelpText(@help_text2)
      when :overview
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

  private

    # @see #HandleEvent
    def edit_entry(source_entry, entryno)
      entry = GetFstabEntry(source_entry, Builtins.remove(@nfs_entries, entryno))

      return unless entry

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
end
