# encoding: utf-8

# File:
#   Nfs.ycp
#
# Module:
#   Configuration of nfs
#
# Summary:
#   NFS client configuration data, I/O functions.
#
# Authors:
#   Jan Holesovsky <kendy@suse.cz>
#   Dan Vesely <dan@suse.cz>
#   Martin Vidner <mvidner@suse.cz>
#
# $Id$
require "yast"

module Yast
  class NfsClass < Module
    def main

      textdomain "nfs"

      Yast.import "FileUtils"
      Yast.import "Mode"
      Yast.import "NfsOptions"
      Yast.import "Report"
      Yast.import "Service"
      Yast.import "Summary"
      Yast.import "SuSEFirewall"
      Yast.import "Progress"
      Yast.import "PackageSystem"
      Yast.import "PackagesProposal"
      Yast.import "Wizard"
      Yast.import "Message"

      Yast.include self, "nfs/routines.rb"


      # default value of settings modified
      @modified = false

      # Should fstab reading be skipped ? (yes if we're
      # embedded in partitioner)
      @skip_fstab = false

      # Required packages
      @required_packages = ["nfs-client"]

      # eg.: [ $["spec": "moon:/cheese", file: "/mooncheese", "mntops": "defaults"], ...]
      @nfs_entries = []

      # Read only, intended for checking mount-point uniqueness.
      @non_nfs_entries = []

      @nfs4_enabled = nil

      @nfs_gss_enabled = nil

      @idmapd_domain = ""

      @portmapper = ""

      # list of created directories
      @created_dirs = []
    end

    # Function sets internal variable, which indicates, that any
    # settings were modified, to "true"
    def SetModified
      @modified = true

      nil
    end

    # Functions which returns if the settings were modified
    # @return [Boolean]  settings were modified
    def GetModified
      @modified
    end

    def ReadNfs4
      SCR.Read(path(".sysconfig.nfs.NFS4_SUPPORT")) == "yes"
    end

    def ReadNfsGss
      SCR.Read(path(".sysconfig.nfs.NFS_SECURITY_GSS")) == "yes"
    end

    def ReadIdmapd
      Convert.to_string(SCR.Read(path(".etc.idmapd_conf.value.General.Domain")))
    end

    def ValidateAyNfsEntry(entry)
      entry = deep_copy(entry)
      valid = true
      Builtins.foreach(["server_path", "mount_point", "nfs_options"]) do |k|
        if !Builtins.haskey(entry, k)
          Builtins.y2error("Missing at Import: '%1'.", k)
          valid = false
        end
      end
      valid
    end

    def GetOptionsAndEntriesSLE11(settings, global_options, entries)
      settings = deep_copy(settings)
      if Builtins.haskey(Ops.get(settings, 0, {}), "enable_nfs4") ||
          Builtins.haskey(Ops.get(settings, 0, {}), "idmapd_domain")
        global_options.value = Ops.get(settings, 0, {})
        settings = Builtins.remove(settings, 0)
      end

      entries.value = Convert.convert(
        settings,
        :from => "list <map>",
        :to   => "list <map <string, any>>"
      )

      nil
    end


    def GetOptionsAndEntriesMap(settings, global_options, entries)
      settings = deep_copy(settings)
      global_options.value = Builtins.remove(settings, "nfs_entries")
      entries.value = Ops.get_list(settings, "nfs_entries", [])

      nil
    end

    # From settings (which is a list in SLE11 but a map in oS: bnc#820989),
    # extract the options and the NFS fstab entries.
    def GetOptionsAndEntries(any_settings, global_options, entries)
      any_settings = deep_copy(any_settings)
      # map: oS;
      if Ops.is_map?(any_settings)
        global_options_ref = arg_ref(global_options.value)
        entries_ref = arg_ref(entries.value)
        GetOptionsAndEntriesMap(
          Convert.to_map(any_settings),
          global_options_ref,
          entries_ref
        )
        global_options.value = global_options_ref.value
        entries.value = entries_ref.value
      elsif Ops.is(any_settings, "list <map>")
        global_options_ref = arg_ref(global_options.value)
        entries_ref = arg_ref(entries.value)
        GetOptionsAndEntriesSLE11(
          Convert.convert(any_settings, :from => "any", :to => "list <map>"),
          global_options_ref,
          entries_ref
        )
        global_options.value = global_options_ref.value
        entries.value = entries_ref.value
      else
        Builtins.y2internal(
          "Cannot happen, got neither a map nor a list: %1",
          any_settings
        )
      end

      nil
    end

    # Fill in the defaults for AY profile entries.
    def FillEntriesDefaults(entries)
      entries = deep_copy(entries)
      Builtins.maplist(entries) do |e|
        #Backwards compatibility: with FaTE#302031, we support nfsv4 mounts
        #thus we need to keep info on nfs version (v3 vs. v4)
        #But older AY profiles might not contain this element
        #so let's assume nfsv3 in that case (#395850)
        Ops.set(e, "vfstype", "nfs") if !Builtins.haskey(e, "vfstype")
        deep_copy(e)
      end
    end

    def ImportAny(settings)
      settings = deep_copy(settings)
      # ($) since oS-1x.x, settings was changed to be a map,
      # which is incompatible with the sle profiles;
      # it owuld be nice to make it compatible again
      # whjich this code is readyu to, but the Autoyast engine isn't.
      global_options = {}
      entries = []
      global_options_ref = arg_ref(global_options)
      entries_ref = arg_ref(entries)
      GetOptionsAndEntries(settings, global_options_ref, entries_ref)
      global_options = global_options_ref.value
      entries = entries_ref.value

      return false if Builtins.find(entries) { |e| !ValidateAyNfsEntry(e) } != nil

      entries = FillEntriesDefaults(entries)

      @nfs4_enabled = Ops.get_boolean(global_options, "enable_nfs4") do
        ReadNfs4()
      end
      @nfs_gss_enabled = Ops.get_boolean(global_options, "enable_nfs_gss") do
        ReadNfsGss()
      end
      @idmapd_domain = Ops.get_string(global_options, "idmapd_domain") do
        ReadIdmapd()
      end

      # vfstype can override a missing enable_nfs4
      @nfs4_enabled = true if Builtins.find(entries) do |entry|
        Ops.get_string(entry, "vfstype", "") == "nfs4"
      end != nil

      @nfs_entries = Builtins.maplist(entries) do |entry|
        {
          "spec"    => Ops.get_string(entry, "server_path", ""),
          "file"    => Ops.get_string(entry, "mount_point", ""),
          "vfstype" => Ops.get_string(entry, "vfstype", ""),
          "mntops"  => Ops.get_string(entry, "nfs_options", "")
        }
      end

      true
    end

    # Get all NFS configuration from a map.
    # When called by nfs_auto (preparing autoinstallation data)
    # the map may be empty.
    # @param [Hash{String => Object}] settings	a map($) of nfs_entries
    # @return	success
    def Import(settings)
      settings = deep_copy(settings)
      ImportAny(settings)
    end

    # Dump the NFS settings to a map, for autoinstallation use.
    # @return a list of nfs entries.
    def Export
      settings = {}

      Ops.set(settings, "enable_nfs4", @nfs4_enabled)
      Ops.set(settings, "enable_nfs_gss", @nfs_gss_enabled)
      Ops.set(settings, "idmapd_domain", @idmapd_domain)

      entries = Builtins.maplist(@nfs_entries) do |entry|
        {
          "server_path" => Ops.get_string(entry, "spec", ""),
          "mount_point" => Ops.get_string(entry, "file", ""),
          "vfstype"     => Ops.get_string(entry, "vfstype", ""),
          "nfs_options" => Ops.get_string(entry, "mntops", "")
        }
      end
      Ops.set(settings, "nfs_entries", entries)
      deep_copy(settings)
    end

    # ------------------------------------------------------------
    # Space escaping.
    # This should be done by the agent, but any-agent sucks.

    # Escape spaces " " -> "\\040".
    # @param [String] s a string or nil
    # @return escaped string or nil
    def EscapeSpaces1(s)
      s == nil ?
        nil :
        Builtins.mergestring(Builtins.splitstring(s, " "), "\\040")
    end

    # Escape spaces " " -> "\\040" in all values of all entries
    # @param [Array<Hash{String => Object>}] entries a list of maps, such as nfs_entries
    # @return escaped entries
    def EscapeSpaces(entries)
      entries = deep_copy(entries)
      Builtins.maplist(entries) { |entry| Builtins.mapmap(entry) do |key, value|
        {
          key => Ops.is_string?(value) ?
            EscapeSpaces1(Convert.to_string(value)) :
            value
        }
      end }
    end

    # (like awk gsub, but return the result, not number of replacements)
    # replaces from back!
    # @param [String] regex regular expression to replace
    # @param [String] replacement the replacement string
    # @param [String] s where to replace
    # @return the changed string
    def gsub(regex, replacement, s)
      temp = nil
      while true
        # argh, regexpsub logs an error if it cannot sub
        break if !Builtins.regexpmatch(s, Ops.add(Ops.add(".*", regex), ".*"))
        temp = Builtins.regexpsub(
          s,
          Ops.add(Ops.add("(.*)", regex), "(.*)"),
          Ops.add(Ops.add("\\1", replacement), "\\2")
        )
        break if temp == nil
        s = temp
      end
      s
    end

    # Un-escape spaces "\\040" -> " "
    # @param [String] s string or nil
    # @return escaped string or nil
    def UnescapeSpaces1(s)
      # escaped space, \040, is /\\040/
      # which is "\\\\040"
      s == nil ? nil : gsub("\\\\040", " ", s)
    end

    # Un-escape spaces "\\040" -> " " in all values of all entries
    # @param [Array<Hash{String => Object>}] entries a list of maps, such as nfs_entries
    # @return escaped entries
    def UnescapeSpaces(entries)
      entries = deep_copy(entries)
      Builtins.maplist(entries) { |entry| Builtins.mapmap(entry) do |key, value|
        {
          key => Ops.is_string?(value) ?
            UnescapeSpaces1(Convert.to_string(value)) :
            value
        }
      end }
    end

    def FindPortmapper
      #testsuite is dumb - it can't distinguish between the existence
      #of two services - either both exists or both do not
      return "portmap" if Mode.testsuite
      Service.Find(["rpcbind", "portmap"])
    end

    # ------------------------------------------------------------

    # Reads NFS settings from the SCR (.etc.fstab)
    # @return true on success
    def Read
      #Read /etc/fstab if we're running standalone (otherwise, libstorage does the job)
      if !@skip_fstab
        fstab = Convert.convert(
          SCR.Read(path(".etc.fstab")),
          :from => "any",
          :to   => "list <map <string, any>>"
        )
        fstab = UnescapeSpaces(fstab)
        Builtins.y2milestone("fstab: %1", fstab)

        # For simplicity, this leaves also the unused fileds in the maps.
        @nfs_entries = Builtins.filter(fstab) do |entry|
          Ops.get_string(entry, "vfstype", "") == "nfs" ||
            Ops.get_string(entry, "vfstype", "") == "nfs4"
        end
        @non_nfs_entries = Builtins.filter(fstab) do |entry|
          Ops.get_string(entry, "vfstype", "") != "nfs" &&
            Ops.get_string(entry, "vfstype", "") != "nfs4"
        end
      end

      @nfs4_enabled = ReadNfs4()
      @nfs_gss_enabled = ReadNfsGss()
      @idmapd_domain = ReadIdmapd()

      progress_orig = Progress.set(false)
      SuSEFirewall.Read
      Progress.set(progress_orig)

      @portmapper = FindPortmapper()
      #There is neither rpcbind  nor portmap
      if @portmapper == ""
        #so let's install rpcbind (default since #423026)
        @required_packages = Builtins.add(@required_packages, "rpcbind")
        @portmapper = "rpcbind"
      end
      if @nfs4_enabled
        @required_packages = Builtins.add(@required_packages, "nfsidmap")
      end

      if Mode.installation
        Builtins.foreach(@required_packages) do |p|
          PackagesProposal.AddResolvables("yast2-nfs-client", :package, [p])
        end
      else
        if !PackageSystem.CheckAndInstallPackagesInteractive(@required_packages)
          return false
        end
      end

      true
    end

    # Writes the NFS client configuration without
    # starting/stopping the service.
    # Autoinstallation uses this and then calls SuSEconfig only once
    # and starts the services together.
    # (No parameters because it is too short to abort)
    # @return true on success
    def WriteOnly
      # Merge with non-nfs entries from fstab:
      fstab = Convert.convert(
        SCR.Read(path(".etc.fstab")),
        :from => "any",
        :to   => "list <map <string, any>>"
      )
      # unescape deferred for optimization
      fstab = Builtins.filter(fstab) do |entry|
        Ops.get_string(entry, "vfstype", "") != "nfs" &&
          Ops.get_string(entry, "vfstype", "") != "nfs4"
      end
      fstab = UnescapeSpaces(fstab)

      Builtins.foreach(@nfs_entries) do |entry|
        fstab = Builtins.add(
          fstab,
          Convert.convert(
            Builtins.union(
              entry,
              { "freq" => 0, "passno" => 0 } #"vfstype": "nfs",
            ),
            :from => "map",
            :to   => "map <string, any>"
          )
        )
        # create mount points
        file = Ops.get_string(entry, "file", "")
        if !Convert.to_boolean(SCR.Execute(path(".target.mkdir"), file))
          # error popup message
          Report.Warning(
            Builtins.sformat(_("Unable to create directory '%1'."), file)
          )
        end
      end

      Builtins.y2milestone("fstab: %1", fstab)

      SCR.Execute(
        path(".target.bash"),
        "/bin/cp $ORIG $BACKUP",
        { "ORIG" => "/etc/fstab", "BACKUP" => "/etc/fstab.YaST2.save" }
      )

      fstab = EscapeSpaces(fstab)
      if !SCR.Write(path(".etc.fstab"), fstab)
        # error popup message
        Report.Error(
          _(
            "Unable to write to /etc/fstab.\n" \
              "No changes will be made to the\n" \
              "the NFS client configuration.\n"
          )
        )
        return false
      end

      @portmapper = FindPortmapper()
      if Builtins.size(@nfs_entries) != 0
        Service.Enable(@portmapper)
        Service.Enable("nfs")
      end

      if @nfs4_enabled == true
        SCR.Write(path(".sysconfig.nfs.NFS4_SUPPORT"), "yes")
        SCR.Write(path(".etc.idmapd_conf.value.General.Domain"), @idmapd_domain)
        # flush the changes
        SCR.Write(path(".etc.idmapd_conf"), nil)
      elsif @nfs4_enabled == false
        SCR.Write(path(".sysconfig.nfs.NFS4_SUPPORT"), "no")
      end
      SCR.Write(
        path(".sysconfig.nfs.NFS_SECURITY_GSS"),
        @nfs_gss_enabled ? "yes" : "no"
      )

      progress_orig = Progress.set(false)
      SuSEFirewall.WriteOnly
      Progress.set(progress_orig)

      true
    end

    # Writes the NFS client configuration and starts/stops the service.
    # (No parameters because it is too short to abort)
    # @return true on success
    def Write
      if WriteOnly()
        # dialog label
        Progress.New(
          _("Writing NFS Configuration"),
          " ",
          2,
          [
            # progress stage label
            _("Stop services"),
            # progress stage label
            _("Start services")
          ],
          [
            # progress step label
            _("Stopping services..."),
            # progress step label
            _("Starting services..."),
            # final progress step label
            _("Finished")
          ],
          ""
        )

        # help text
        Wizard.RestoreHelp(_("Writing NFS client settings. Please wait..."))

        Progress.NextStage

        Service.Stop("nfs")

        Progress.NextStage
        if Ops.greater_than(Builtins.size(@nfs_entries), 0)
          # portmap must not be started if it is running already (see bug # 9999)
          Service.Start(@portmapper) unless Service.active?(@portmapper)

          unless Service.active?(@portmapper)
            Report.Error(Message.CannotStartService(@portmapper))
            return false
          end

          Service.Start("nfs")

          unless Service.active?("nfs")
            # error popup message
            Report.Error(_("Unable to mount the NFS entries from /etc/fstab."))
            return false
          end
        end

        progress_orig = Progress.set(false)
        SuSEFirewall.ActivateConfiguration
        Progress.set(progress_orig)

        Progress.NextStage
        return true
      else
        return false
      end
    end

    # Summary()
    # @return Html formatted configuration summary
    def Summary
      summary = ""
      nc = Summary.NotConfigured
      # summary header
      summary = Summary.AddHeader(summary, _("NFS Entries"))
      entries = Builtins.size(@nfs_entries)
      Builtins.y2milestone("Entries: %1", @nfs_entries)
      # summary item, %1 is a number
      configured = Builtins.sformat(_("%1 entries configured"), entries)
      summary = Summary.AddLine(
        summary,
        Ops.greater_than(entries, 0) ? configured : nc
      )
      summary
    end


    # Mount NFS directory
    # @param [String] server remote server name
    # @param [String] share name of the exported directory
    # @param [String] mpoint mount point (can be empty or nil,
    #                 in this case it will be mounted in a temporary directory)
    # @param [String] options mount options - e.g. "ro,hard,intr", see man nfs
    # @param [String] type nfs type (nfs vs. nfsv4) - if empty, 'nfs' is used
    # @return [String] directory where volume was mounted or nil if mount failed

    def Mount(server, share, mpoint, options, type)
      return nil if Builtins.size(server) == 0 || Builtins.size(share) == 0

      # check if options are valid
      if Ops.greater_than(Builtins.size(options), 0)
        if NfsOptions.validate(options) != ""
          Builtins.y2warning("invalid mount options: %1", options)
          return nil
        end
      end

      # mount to temporary directory if mpoint is nil
      if mpoint == nil
        tmpdir = Convert.to_string(SCR.Read(path(".target.tmpdir")))

        if tmpdir == nil || tmpdir == ""
          Builtins.y2security("Warning: using /tmp directory!")
          tmpdir = "/tmp"
        end

        mpoint = Ops.add(
          Ops.add(tmpdir, "/nfs"),
          Builtins.sformat("%1", Builtins.size(@created_dirs))
        ) # use num to allow parallel mounts
      end

      # check mount point
      if CheckPath(mpoint) == false
        # mount point is not valid
        Builtins.y2warning("invalid mount point: %1", mpoint)
        return nil
      end

      portmapper = FindPortmapper()
      # check whether portmapper is installed
      if IsPortmapperInstalled(portmapper) == false
        Builtins.y2warning("Neither rpcbind nor portmap is installed")
        return nil
      end


      # start portmapper if it isn't running
      unless Service.active?(portmapper)
        unless Service.Start(portmapper)
          Builtins.y2warning("%1 cannot be started", portmapper)
          return nil
        end
      end

      # create mount point if it doesn't exist
      if SCR.Read(path(".target.dir"), mpoint) == nil
        if !Convert.to_boolean(SCR.Execute(path(".target.mkdir"), mpoint))
          Builtins.y2warning("cannot create mount point %1", mpoint)
          return nil
        end

        # remember name of created directory
        @created_dirs = Builtins.add(@created_dirs, mpoint)
      end

      # build mount command
      command = Builtins.sformat(
        "/bin/mount %1 %2 %3:%4 %5",
        Ops.greater_than(Builtins.size(options), 0) ?
          Ops.add("-o ", options) :
          "",
        Ops.add("-t ", Ops.greater_than(Builtins.size(type), 0) ? type : "nfs"),
        server,
        share,
        mpoint
      )

      # execute mount command
      SCR.Execute(path(".target.bash"), command) == 0 ? mpoint : nil
    end

    # Unmount NFS directory from the system
    # @param [String] mpoint NFS mount point to unmount
    # @return [Boolean] true on success
    def Unmount(mpoint)
      return false if Builtins.size(mpoint) == 0

      # unmount directory if it's NFS mountpoint
      mounts = Convert.convert(
        SCR.Read(path(".proc.mounts")),
        :from => "any",
        :to   => "list <map <string, any>>"
      )
      found = false

      Builtins.foreach(mounts) do |m|
        type = Ops.get_string(m, "vfstype")
        file = Ops.get_string(m, "file")
        found = true if (type == "nfs" || type == "nfs4") && file == mpoint
      end 


      if found
        command = Builtins.sformat("/bin/umount %1", mpoint)

        return false if SCR.Execute(path(".target.bash"), command) != 0
      else
        Builtins.y2warning("%1 is not NFS mount point", mpoint)
        return false
      end

      # if the directory was created by Mount call and it is empty then remove it
      if Builtins.contains(@created_dirs, mpoint) &&
          SCR.Read(path(".target.dir"), mpoint) == []
        command = Builtins.sformat("/bin/rmdir %1", mpoint)

        return false if SCR.Execute(path(".target.bash"), command) != 0

        # remove directory from list
        @created_dirs = Builtins.filter(@created_dirs) { |d| d != mpoint }
      end

      true
    end

    # Return required packages for auto-installation
    # @return [Hash] of packages to be installed and to be removed
    def AutoPackages
      { "install" => @required_packages, "remove" => [] }
    end

    # Probe the LAN for NFS servers.
    # Uses RPC broadcast to mountd.
    # @return a list of hostnames
    def ProbeServers
      #newer, shinier, better rpcinfo from rpcbind (#450056)
      prog_name = "/sbin/rpcinfo"
      delim = ""

      #fallback from glibc (uses different field separators, grr :( )
      if !FileUtils.Exists(prog_name)
        prog_name = "/usr/sbin/rpcinfo"
        delim = "-d ' ' "
      end

      # #71064
      # this works also if ICMP broadcasts are ignored
      cmd = Ops.add(
        Ops.add(Ops.add(prog_name, " -b mountd 1 | cut "), delim),
        "-f 2 | sort -u"
      )
      out = Convert.to_map(SCR.Execute(path(".target.bash_output"), cmd))
      hosts = Builtins.filter(
        Builtins.splitstring(Ops.get_string(out, "stdout", ""), "\n")
      ) { |s| s != "" }
      deep_copy(hosts)
    end

    # Probe a server for its exports.
    # @param [String] server IP or hostname
    # @param [Boolean] v4 Use NFSv4?
    # @return a list of exported paths
    def ProbeExports(server, v4)
      dirs = []

      # showmounts does not work for nfsv4 (#466454)
      if v4
        tmpdir = Mount(server, "/", nil, "ro", "nfs4")

        # This is completely stupid way how to explore what can be mounted
        # and I even don't know if it is correct. Maybe 'find tmpdir -xdev -type d'
        # should be used instead. No clue :(
        dirs = Builtins.maplist(
          Convert.convert(
            SCR.Read(path(".target.dir"), tmpdir),
            :from => "any",
            :to   => "list <string>"
          )
        ) { |dirent| Ops.add("/", dirent) }
        dirs = Builtins.prepend(dirs, "/")
        Unmount(tmpdir)
      else
        dirs = Convert.convert(
          SCR.Read(path(".net.showexports"), server),
          :from => "any",
          :to   => "list <string>"
        )
      end

      dirs = ["internal error"] if dirs == nil
      deep_copy(dirs)
    end

    publish :variable => :modified, :type => "boolean"
    publish :variable => :skip_fstab, :type => "boolean"
    publish :function => :SetModified, :type => "void ()"
    publish :function => :GetModified, :type => "boolean ()"
    publish :variable => :required_packages, :type => "list <string>"
    publish :variable => :nfs_entries, :type => "list <map <string, any>>"
    publish :variable => :non_nfs_entries, :type => "list <map>"
    publish :variable => :nfs4_enabled, :type => "boolean"
    publish :variable => :nfs_gss_enabled, :type => "boolean"
    publish :variable => :idmapd_domain, :type => "string"
    publish :function => :Import, :type => "boolean (map <string, any>)"
    publish :function => :Export, :type => "map ()"
    publish :function => :FindPortmapper, :type => "string ()"
    publish :function => :Read, :type => "boolean ()"
    publish :function => :WriteOnly, :type => "boolean ()"
    publish :function => :Write, :type => "boolean ()"
    publish :function => :Summary, :type => "string ()"
    publish :function => :Mount, :type => "string (string, string, string, string, string)"
    publish :function => :Unmount, :type => "boolean (string)"
    publish :function => :AutoPackages, :type => "map ()"
    publish :function => :ProbeServers, :type => "list <string> ()"
    publish :function => :ProbeExports, :type => "list <string> (string, boolean)"
  end

  Nfs = NfsClass.new
  Nfs.main
end
