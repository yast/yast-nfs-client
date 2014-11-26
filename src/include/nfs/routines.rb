# encoding: utf-8

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
    end

    # @param [String] spec      "server:/path/specification"
    # @return          `couple("server", "/path/specification")
    def SpecToServPath(spec)
      # split using ":/" (because of IPv6)
      path_begin = Builtins.search(spec, ":/")
      serv = ""

      # no :/ inside => <server>: or [/]<path>
      if path_begin == nil
        if spec ==
            Ops.add(
              Builtins.filterchars(spec, Ops.add("-_.", String.CAlnum)),
              ":"
            )
          # matches [a-zA-Z0-1.-_] and ends with colon? => <server>:
          path_begin = Ops.subtract(Builtins.size(spec), 1)
        end
      end

      if path_begin != nil
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
        it = Item(
          Id(count),
          Ops.add(Ops.get_string(sp, 0, ""), " "),
          Ops.add(Ops.get_string(sp, 1, ""), " "),
          Ops.add(Ops.get_string(entry, "file", ""), " "),
          Ops.get_string(entry, "vfstype", " "),
          Ops.add(Ops.get_string(entry, "mntops", ""), " ")
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
    # @param [Array<Hash>] fstab     in .etc.fstab format (must contain the key "file")
    # @param [String] mpoint    mount point
    # @return          is it there?
    def IsMpInFstab(fstab, mpoint)
      fstab = deep_copy(fstab)
      tmp = Builtins.filter(fstab) do |fse|
        Ops.get_string(fse, "file", "") == mpoint
      end

      if Builtins.size(tmp) == 0
        return false
      else
        # error popup message
        Report.Error(
          Builtins.sformat(
            _("fstab already contains an entry\nwith mount point '%1'."),
            mpoint
          )
        )
      end
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
      if Builtins.regexpmatch(p, "^.+/$")
        return Builtins.regexpsub(p, "^(.+)/$", "\\1")
      else
        return p
      end
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
  end
end
