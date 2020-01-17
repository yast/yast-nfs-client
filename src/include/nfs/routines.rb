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

require "y2nfs_client/nfs_version"
require "y2storage"

# YaST namespace
module Yast
  # Miscellaneous
  module NfsRoutinesInclude
    def initialize_nfs_routines(_include_target)
      textdomain "nfs"

      Yast.import "Package"
      Yast.import "Report"
      Yast.import "IP"
      Yast.import "Hostname"
      Yast.import "String"
      Yast.import "NfsOptions"
    end

    # @param [String] spec      "server:/path/specification"
    # @return          `couple("server", "/path/specification")
    def SpecToServPath(spec)
      # split using ":/" (because of IPv6)
      path_begin = Builtins.search(spec, ":/")
      serv = ""

      # no :/ inside => <server>: or [/]<path>
      if path_begin.nil?
        if spec ==
            Ops.add(
              Builtins.filterchars(spec, Ops.add("-_.", String.CAlnum)),
              ":"
            )
          # matches [a-zA-Z0-1.-_] and ends with colon? => <server>:
          path_begin = Ops.subtract(Builtins.size(spec), 1)
        end
      end

      if path_begin
        serv = Builtins.substring(spec, 0, path_begin)
        spec = Builtins.substring(spec, Ops.add(path_begin, 1))
      end
      term(:couple, serv, spec)
    end

    # Creates a list of ui table items for nfs fstab entries
    # @param [Array<Hash>] fstab     list of nfs fstab entries
    # @return          itemized table entries
    # @example UI::ChangeWidget(`id(`fstable), `Items, FstabTableItems(nfs_entries));
    def FstabTableItems(fstab)
      fstab = deep_copy(fstab)
      count = 0
      Builtins.maplist(fstab) do |entry|
        sp = SpecToServPath(Ops.get_string(entry, "spec", ""))
        mount_point = item_mount_point(entry)
        mntops = entry["mntops"] || ""

        it = Item(
          Id(count),
          Ops.get_string(sp, 0, "") + " ",
          Ops.get_string(sp, 1, "") + " ",
          mount_point + " ",
          nfs_version_for_table(entry) + " ",
          mntops + " "
        )

        count = Ops.add(count, 1)
        deep_copy(it)
      end
    end

    # Check for the validity of a hostname: nonempty, shorter than 50 chars,
    # [-A-Za-z._]. If invalid, a message is displayed.
    # @param [String] name      a hostname
    # @return          whether valid
    def CheckHostName(name)
      Builtins.y2milestone("CheckHostName: hostname=%1", name)

      if Ops.greater_than(Builtins.size(name), 0) &&
          Ops.less_than(Builtins.size(name), 50)
        return true if IP.Check4(name)
        return true if IP.Check6(IP.UndecorateIPv6(name))
        return true if Hostname.CheckDomain(name)
      end

      # error popup message

      Report.Error(
        Builtins.sformat(
          _(
            "The hostname entered is invalid. It must be\n" \
              "shorter than 50 characters and only use\n" \
              "valid IPv4, IPv6 or domain name.\n" \
              "Valid IPv4: %1\n" \
              "Valid IPv6: %2\n" \
              "Valid domain: %3"
          ),
          IP.Valid4,
          IP.Valid6,
          Hostname.ValidDomain
        )
      )

      false
    end

    # Check if a mountpoint is in the fstab. If yes, display a message.
    #
    # This method checks against all the mount points not handled by the
    # yast-nfs-client module (i.e. non-NFS entries in fstab) and against the
    # list of NFS shares currently managed by the module (provided as argument).
    #
    # @param nfs_entries [Array<Hash>] list of NFS entries to check in addition
    #   to the known non-NFS mount points. The NFS entries must be in .etc.fstab
    #   format (must contain the key "file")
    # @param mpoint [String] mount point
    # @return          is it there?
    def IsMpInFstab(nfs_entries, mpoint)
      found = non_nfs_mount_paths.any?(mpoint)
      found ||= nfs_entries.any? { |fse| fse["file"] == mpoint }

      return false unless found

      # error popup message
      Report.Error(
        Builtins.sformat(
          _("fstab already contains an entry\nwith mount point '%1'."),
          mpoint
        )
      )
      true
    end

    # Check for the validity of a path/mountpoint:
    # nonempty, fewer than 70 chars, starts with a slash.
    # If invalid, a message is displayed.
    # @param [String] name      path
    # @return          whether valid
    def CheckPath(name)
      if Ops.greater_than(Builtins.size(name), 0) &&
          Ops.less_than(Builtins.size(name), 70) &&
          Builtins.substring(name, 0, 1) == "/"
        return true
      end

      # error popup message (spaces are now allowed)
      Report.Error(
        Builtins.sformat(
          _(
            "The path entered is invalid.\n" \
              "It must be shorter than 70 characters\n" \
              "and it must begin with a slash (/)."
          )
        )
      )
      false
    end

    # Strips a superfluous slash off the end of a pathname.
    # @param [String] p       pathname
    # @return          stripped pathname
    def StripExtraSlash(p)
      Builtins.regexpmatch(p, "^.+/$") ? Builtins.regexpsub(p, "^(.+)/$", "\\1") : p
    end

    # Formats hostname into form suitable for fstab.
    # If given param is IPv6 then encloses it into square brackets.
    def FormatHostnameForFstab(hostname)
      Builtins.y2milestone("FormatHostnameForFstab: hostname=%1", hostname)

      if IP.Check6(IP.UndecorateIPv6(hostname))
        return Builtins.sformat(
          Builtins.regexpmatch(hostname, "\\[.*\\]") ? "%1" : "[%1]",
          hostname
        )
      end
      hostname
    end

    # Check whether pormap is installed, ask user to install it if it is missing
    # @return [Boolean] true if portmap is installed
    def IsPortmapperInstalled(portmapper)
      Package.Install(portmapper)
    end

    # Whether the fstab entry uses old ways of configuring the NFS version that
    # do not longer work in the way they used to.
    #
    # @param entry [Hash]
    # @return [Boolean]
    def legacy_entry?(entry)
      entry["vfstype"] == "nfs4" || NfsOptions.legacy?(entry["mntops"] || "")
    end

    # Transforms a hash representing an NFS mount from the internal format used
    # by yast-nfs-client to the TargetMap format used by the old yast-storage
    #
    # This is a direct translation of the old NfsClient4partClient#ToStorage
    #
    # @param entry [Hash] NFS mount in the internal format that uses keys as
    #   "spec", "file", etc.
    # @return [Hash] NFS mount in the TargetMap format that uses keys as
    #   "device", "mount", etc.
    def fstab_to_storage(entry)
      ret = {}

      if entry && entry != {}
        ret = {
          "device"  => entry.fetch("spec", ""),
          "mount"   => entry.fetch("file", ""),
          "fstopt"  => entry.fetch("mntops", ""),
          "vfstype" => entry.fetch("vfstype", "nfs")
        }
        # The "old" and "old_device" keys are used by nfs-client to indicate to
        # the storage stack that an entry is not new, but a replacement for one
        # of the entries originally reported by the storage stack. Thus, is only
        # needed in this direction (from fstab to storage).
        ret["old_device"] = entry["old"] if entry["old"]
      end
      ret
    end

    # Inverse of {#fstab_to_storage}
    #
    # @param entry [Hash] see return value of {#fstab_to_storage}
    # @return [Hash] see argument of {#fstab_to_storage}
    def storage_to_fstab(entry)
      return {} if entry.nil? || entry.empty?

      {
        "spec"    => entry.fetch("device", ""),
        "file"    => entry.fetch("mount", ""),
        "vfstype" => entry.fetch("used_fs", :nfs) == :nfs ? "nfs" : "nfs4",
        "mntops"  => entry.fetch("fstopt", "")
      }
    end

    # Creates a LegacyNfs object according to the given entry
    #
    # @param entry [Hash] NFS mount in the .etc.fstab format that uses keys such as "spec", "file", etc.
    # @return [Y2Storage::Filesystems::LegacyNfs]
    def to_legacy_nfs(entry)
      storage_hash = fstab_to_storage(entry)
      legacy = Y2Storage::Filesystems::LegacyNfs.new_from_hash(storage_hash)
      legacy.default_devicegraph = working_graph

      legacy
    end

  private

    # @see #FstabTableItems
    #
    # @param entry [Hash]
    # @return [String]
    def nfs_version_for_table(entry)
      mntops = entry["mntops"] || ""
      version = NfsOptions.nfs_version(mntops)

      if legacy_entry?(entry)
        # TRANSLATORS: %s is a string representing the NFS version used, but
        # maybe it's not the one the user wanted.
        _("%s (Please Check)") % version.label
      else
        version.label
      end
    end

    # Singleton instance of Y2Storage::StorageManager
    #
    # @return [Y2Storage::StorageManager]
    def storage_manager
      Y2Storage::StorageManager.instance
    end

    # Devicegraph to operate with
    #
    # @return [Y2Storage::Devicegraph]
    def working_graph
      storage_manager.staging
    end

    # Devicegraph representing the current system status
    #
    # @return [Y2Storage::Devicegraph]
    def system_graph
      storage_manager.probed
    end

    # Mount points present on /etc/fstab but not handled by the yast-nfs-client
    # module.
    #
    # @return [Array<String>]
    def non_nfs_mount_paths
      Y2Storage::MountPoint.all(working_graph).select do |mp|
        mp.mountable && !mp.mountable.is?(:nfs)
      end.map(&:path)
    end

    # Mount point to show for the given entry
    #
    # Note that an asterisk could be appended to the mount path when the NFS share is not currently
    # mounted.
    #
    # @param entry [Hash] NFS mount in the .etc.fstab format that uses keys such as "spec", "file", etc.
    # @return [String]
    def item_mount_point(entry)
      mount_point = entry["file"].dup || ""

      mount_point << "*" if unmounted_mark?(entry)

      mount_point
    end

    # Whether a mark should be added to the mount path because the device is unmounted
    #
    # @param entry [Hash] NFS mount in the .etc.fstab format that uses keys such as "spec", "file", etc.
    # @return [Boolean]
    def unmounted_mark?(entry)
      return false if entry["new"]

      nfs = to_legacy_nfs(entry).find_nfs_device

      nfs && nfs.mount_point && nfs.mount_point.active? ? false : true
    end
  end
end
