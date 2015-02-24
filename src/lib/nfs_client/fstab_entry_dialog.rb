# Copyright (c) 2015 SUSE LLC.
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

require "yast"
require "ui/dialog"

Yast.import "UI"
Yast.import "Wizard"
Yast.import "Label"
Yast.import "Hostname"
Yast.import "Nfs"
Yast.import "NfsOptions"
Yast.import "SuSEFirewall"
Yast.import "Report"
Yast.import "Popup"
Yast.import "FileUtils"

module NfsClient
  # Dialog to ask the user for an entry in /etc/fstab
  class FstabEntryDialog < UI::Dialog

    # @param fstab_ent [Hash{String => Object}] $["spec": "file": "mntops":] or nil
    # @param existing [Array<Hash>] list of fstab entries for duplicate mount-point checking
    # @param nfs_entries [Array<Hash>] list of already defined nfs mount points
    def initialize(fstab_ent, existing, nfs_entries)
      super()
      textdomain "nfs"
      Yast.include self, "nfs/routines.rb"
      @fstab_ent = fstab_ent
      @existing = existing

      # Caches names of nfs servers
      @hosts = nil

      Yast::Wizard.SetScreenShotName("nfs-client-1a-edit")

      @server = ""
      @pth = ""
      @mount = ""
      @nfs4 = false
      @nfs41 = false
      @options = "defaults"
      @servers = []
      @server = nil
      @old = ""

      if @fstab_ent
        couple = SpecToServPath(@fstab_ent.fetch("spec", ""))
        @server = couple[0] || ""
        @servers = [@server]
        @pth = couple[1] || ""
        @mount = @fstab_ent.fetch("file", "")
        @nfs4 = @fstab_ent.fetch("vfstype", "") == "nfs4"
        @options = @fstab_ent.fetch("mntops", "")
        @nfs41 = @nfs4 && Yast::NfsOptions.get_nfs41(@options)
        @old = @fstab_ent.fetch("spec", "")
      else
        proposed_server = ProposeHostname()
        @servers = [proposed_server] if HostnameExists(proposed_server)
      end

      # append already defined servers - bug #547983
      nfs_entries.each do |nfs_entry|
        couple = SpecToServPath(nfs_entry.fetch("spec", ""))
        known_server = couple[0] || ""
        @servers << known_server unless @servers.include?(known_server)
      end

      @servers.sort!
    end

    # Main layout
    def dialog_content
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
                @servers
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
                @pth
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
              CheckBox(Id(:nfs4), _("NFS&v4 Share"), @nfs4),
              HSpacing(2),
              # parallel NFS, protocol version 4.1
              CheckBox(Id(:nfs41), _("pNFS (v4.1)"), @nfs41)
            )
          ),
          Left(
            TextAndButton(
              InputField(
                Id(:mountent),
                Opt(:hstretch),
                # textentry label
                _("&Mount Point (local)"),
                @mount
              ),
              # button label
              # browse directories to select a mount point
              # appears in help text too
              PushButton(Id(:browse), _("&Browse"))
            )
          ),
          # textentry label
          VSpacing(0.2),
          InputField(Id(:optionsent), Opt(:hstretch), _("O&ptions"), @options),
          VSpacing(0.2),
          ButtonBox(
            PushButton(Id(:ok), Opt(:default, :key_F10), Yast::Label.OKButton),
            PushButton(Id(:cancel), Opt(:key_F9), Yast::Label.CancelButton),
            PushButton(Id(:help), Opt(:key_F1), Yast::Label.HelpButton)
          ),
          VSpacing(0.2)
        ),
        HSpacing(1)
      )
    end

    # Dialog options
    def dialog_options
      Opt(:decorated)
    end

    # Event callback for the 'ok' button
    def choose_handler
      if @hosts.nil?
        # label message
        Yast::UI.OpenDialog(Label(_("Scanning for hosts on this LAN...")))
        @hosts = Yast::Nfs.ProbeServers
        Yast::UI.CloseDialog
      end
      if @hosts == [] || @hosts.nil?
        # Translators: 1st part of error message
        error_msg = _("No NFS server has been found on your network.")

        if Yast::SuSEFirewall.GetStartService
          # Translators: 2nd part of error message (1st one is 'No nfs servers have been found ...)
          error_msg << _(
            "\n" \
            "This could be caused by a running SuSEfirewall2,\n" \
            "which probably blocks the network scanning."
          )
        end
        Yast::Report.Error(error_msg)
      else
        host = ChooseHostName(@hosts)
        Yast::UI.ChangeWidget(Id(:serverent), :Value, host) if host
      end
    end

    def pathent_list_handler
      server2 = Yast::UI.QueryWidget(Id(:serverent), :Value).to_s
      v4 = Yast::UI.QueryWidget(Id(:nfs4), :Value)

      if !CheckHostName(server2)
        Yast::UI.SetFocus(Id(:serverent))
        return
      end

      Yast::UI.OpenDialog(
        Label(
          # Popup dialog, %1 is a host name
          Yast::Builtins.sformat(
            _("Getting directory list for \"%1\"..."),
            server2
          )
        )
      )
      dirs = Yast::Nfs.ProbeExports(server2, v4)
      Yast::UI.CloseDialog

      dir = ChooseExport(dirs)
      Yast::UI.ChangeWidget(Id(:pathent), :Value, dir) if dir
    end

    def browse_handler
      dir = Yast::UI.QueryWidget(Id(:mountent), :Value)
      dir = "/" if dir.nil? || dir.empty?

      # heading for a directory selection dialog
      dir = Yast::UI.AskForExistingDirectory(dir, _("Select the Mount Point"))

      if dir && !dir.empty?
        Yast::UI.ChangeWidget(Id(:mountent), :Value, dir)
      end
    end

    def ok_handler
      server = FormatHostnameForFstab(
        Yast::UI.QueryWidget(Id(:serverent), :Value)
      )
      @pth = StripExtraSlash(
        Yast::UI.QueryWidget(Id(:pathent), :Value)
      )
      @mount = StripExtraSlash(
        Yast::UI.QueryWidget(Id(:mountent), :Value)
      )
      @nfs4 = !!Yast::UI.QueryWidget(Id(:nfs4), :Value)
      @nfs41 = !!Yast::UI.QueryWidget(Id(:nfs41), :Value)
      @options = Yast::UI.QueryWidget(Id(:optionsent), :Value).tr(" ", "")
      @options = Yast::NfsOptions.set_nfs41(@options, @nfs41)

      options_error = Yast::NfsOptions.validate(@options)
      if !CheckHostName(server)
        Yast::UI.SetFocus(Id(:serverent))
      elsif !CheckPath(@pth)
        Yast::UI.SetFocus(Id(:pathent))
      elsif !CheckPath(@mount) || IsMpInFstab(@existing, @mount)
        Yast::UI.SetFocus(Id(:mountent))
      elsif options_error.size > 0
        Yast::Popup.Error(options_error)
        Yast::UI.SetFocus(Id(:optionsent))
      else
        @fstab_ent = {
          "spec"    => "#{server}:#{@pth}",
          "file"    => @mount,
          "vfstype" => @nfs4 ? "nfs4" : "nfs",
          "mntops"  => @options
        }
        if @old != "#{server}:#{@pth}"
          @fstab_ent["old"] = @old
        end
        Yast::Wizard.RestoreScreenShotName
        log.info "FstabEntryDialog returns #{@fstab_ent}"
        finish_dialog(@fstab_ent)
      end
    end

    def help_handler
      # help text 1/4
      # change: locally defined -> servers on LAN
      helptext = _(
        "<p>Enter the <b>NFS Server Hostname</b>.  With\n" \
          "<b>Choose</b>, browse through a list of\n" \
          "NFS servers on the local network.</p>\n"
      )
      # help text 2/4
      # added "Select" button
      helptext << _(
        "<p>In <b>Remote File System</b>,\n" \
          "enter the path to the directory on the NFS server.  Use\n" \
          "<b>Select</b> to select one from those exported by the server.\n" \
          "</p>"
      )
      # help text 3/4
      helptext << _(
        "<p>\t\t\n" \
          "For <b>Mount Point</b>, enter the path in the local " \
          "file system where the directory should be mounted. With\n" \
          "<b>Browse</b>, select your mount point\n" \
          "interactively.</p>"
      )
      # help text 4/4
      helptext << _(
        "<p>For a list of <b>Options</b>,\nread the man page mount(8).</p>"
      )
      # popup heading
      Yast::Popup.LongText(_("Help"), RichText(helptext), 50, 18)
    end

    protected

    def create_dialog
      super
      Yast::UI.ChangeWidget(Id(:serverent), :Value, @server)
      Yast::UI.SetFocus(Id(:serverent))
    end

    private

    # Return convenient hostname (FaTE #302863) to be proposed
    # i.e. nfs + current domain (nfs. + suse.cz)
    # @return string	proposed hostname
    def ProposeHostname
      ret = ""
      cur_domain = Yast::Hostname.CurrentDomain

      ret = "nfs.#{cur_domain}" if cur_domain && cur_domain != ""
      ret
    end

    # Let the user choose one of a list of items
    # @param [String] title	selectionbox title
    # @param [Array<String>] items	a list of items
    # @return		one item or nil
    def ChooseItem(title, items)
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
        break if ret == :ok || ret == :cancel
      end

      if ret == :ok
        item = Yast::UI.QueryWidget(Id(:items), :CurrentItem).to_s
      end
      Yast::UI.CloseDialog

      item
    end

    # Give me one name from the list of hosts
    # @param [Array<String>] hosts	a list of hostnames
    # @return		a hostname
    def ChooseHostName(hosts)
      Yast::Wizard.SetScreenShotName("nfs-client-1aa-hosts")
      # selection box label
      # changed from "Remote hosts" because now it shows
      # NFS servers only
      ret = ChooseItem(_("&NFS Servers"), hosts)
      Yast::Wizard.RestoreScreenShotName
      ret
    end

    # Give me one name from the list of exports
    # @param [Array<String>] exports	a list of exports
    # @return		an export
    def ChooseExport(exports)
      Yast::Wizard.SetScreenShotName("nfs-client-1ab-exports")
      # selection box label
      ret = ChooseItem(_("&Exported Directories"), exports)
      Yast::Wizard.RestoreScreenShotName
      ret
    end

    # Find out whether this nfs host really exists
    # @param [String] hname	hostname
    # @return true if it exists, false otherwise
    def HostnameExists(hname)
      prog_name = "/usr/bin/host"
      ret = false

      if Yast::FileUtils.Exists(prog_name)
        out = Yast::SCR.Execute(
          Yast::Path.new(".target.bash_output"),
          "#{prog_name} #{hname}"
        )

        ret = out.fetch("exit", -1) == 0
        log.debug "DNS lookup of #{hname} returned #{ret}"
      else
        log.warn "Cannot DNS lookup #{hname}, will not propose default hostname"
      end

      ret
    end

    # Nicely put a `TextEntry and its helper `PushButton together
    # @param [Yast::Term] text   textentry widget
    # @param [Yast::Term] button pushbutton widget
    # @return a HBox
    def TextAndButton(text, button)
      HBox(Bottom(text), HSpacing(0.5), Bottom(button))
    end
  end
end
