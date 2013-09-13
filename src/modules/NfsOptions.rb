# encoding: utf-8

require "yast"

module Yast
  class NfsOptionsClass < Module
    def main
      textdomain "nfs"
    end

    # Parse to an internal representation:
    # Simply split by commas, but "defaults" is represented by the empty list
    # @param [String] options a fstab option string
    # @return [Array] of individual options
    def from_string(options)
      options = "" if options == "defaults"
      Builtins.splitstring(options, ",")
    end

    # Convert list of individual options to a fstab option string
    # @param [Array<String>] option_list list of individual options
    # @return a fstab option string
    def to_string(option_list)
      option_list = deep_copy(option_list)
      options = Builtins.mergestring(option_list, ",")
      options = "defaults" if options == ""
      options
    end

    # Checks the nfs options for /etc/fstab:
    # nonempty, comma separated list of foo,nofoo,bar=baz (see nfs(5))
    # @param [String] options   options
    # @return          a translated string with error message, emtpy string if ok
    def validate(options)
      # To translators: error popup
      if Builtins.size(options) == 0
        return _("Empty option strings are not allowed.")
      end

      option_list = from_string(options)

      # The options should be kept synced with the code that handles them,
      # which is not an easy task, as there are many places:
      # - util-linux.rpm
      #   man 8 mount
      #   https://git.kernel.org/?p=utils/util-linux/util-linux.git;a=history;f=libmount/src/optmap.c
      # - nfs-client.rpm (nfs-utils.src.rpm)
      #   man 5 nfs
      #   http://git.linux-nfs.org/?p=steved/nfs-utils.git;a=history;f=utils/mount/nfsmount.c
      # - kernel: fs/nfs/super.c
      #   http://git.kernel.org/?p=linux/kernel/git/torvalds/linux.git;a=history;f=fs/nfs/super.c
      # Note that minorversion in particular is mentioned only in the kernel
      # but not in nfs-utils. WTF.

      # these can be negated by "no"
      _NEGATABLE_OPTIONS = [
        "bg",
        "fg",
        "soft",
        "hard",
        "intr",
        "posix",
        "cto",
        "ac",
        "acl",
        "lock",
        "tcp",
        "udp",
        "rdirplus",
        # these are common for all fs types
        "atime",
        "auto",
        "dev",
        "exec",
        "group",
        "owner",
        "suid",
        "user",
        "users"
      ]
      _NEGATED_OPTIONS = Builtins.maplist(_NEGATABLE_OPTIONS) do |e|
        Builtins.sformat("no%1", e)
      end

      # these cannot be negated
      # they are not nfs specific BTW
      _SIMPLE_OPTIONS = [
        "defaults",
        "async",
        "sync",
        "dirsync",
        "ro",
        "rw",
        "remount",
        "bind",
        "rbind",
        "_netdev"
      ]
      _OPTIONS_WITH_VALUE = [
        "rsize",
        "wsize",
        "timeo",
        "retrans",
        "acregmin",
        "acregmax",
        "acdirmin",
        "acdirmin",
        "acdirmax",
        "actimeo",
        "retry",
        "namlen",
        "port",
        "proto",
        "clientaddr",
        "mountport",
        "mounthost",
        "mountprog",
        "mountvers",
        "nfsprog",
        "nfsvers",
        "vers",
        "minorversion",
        "sec"
      ]

      # first fiter out non value options and its nooptions forms (see nfs(5))
      option_list = Builtins.filter(option_list) do |e|
        !Builtins.contains(_NEGATABLE_OPTIONS, e)
      end
      option_list = Builtins.filter(option_list) do |e|
        !Builtins.contains(_NEGATED_OPTIONS, e)
      end
      option_list = Builtins.filter(option_list) do |e|
        !Builtins.contains(_SIMPLE_OPTIONS, e)
      end

      error_message = ""
      Builtins.foreach(option_list) do |opt|
        opt_tuple = Builtins.splitstring(opt, "=")
        key = Ops.get(opt_tuple, 0, "")
        value = Ops.get(opt_tuple, 1, "")
        # By now we have filtered out known options without values;
        # so what is left is either unknown options, ...
        # FIXME: this also triggers for "intr=bogus"
        # because we should have considered '=' before the simple options
        # FIXME "'" + foo + "'" used not to break translations; merge it.
        if !Builtins.contains(_OPTIONS_WITH_VALUE, key)
          # To translators: error popup
          error_message = Builtins.sformat(
            _("Unknown option: %1"),
            Ops.add(Ops.add("'", key), "'")
          )
        # ... or known ones with badly specified values
        elsif Builtins.size(opt_tuple) != 2
          # To translators: error popup
          error_message = Builtins.sformat(
            _("Invalid option: %1"),
            Ops.add(Ops.add("'", opt), "'")
          )
        elsif value == ""
          # To translators: error popup
          error_message = Builtins.sformat(
            _("Empty value for option: %1"),
            Ops.add(Ops.add("'", key), "'")
          )
        end
        raise Break if error_message != ""
      end

      error_message
    end

    # FIXME: factor out get_nfs4(vfstype, options) (depending on n::o)!
    #  * @param options fstab option string
    #  * @return is version >= 4.1 enabled
    def get_nfs41(options)
      option_list = from_string(options)

      _ENABLED = "minorversion=1"
      Builtins.contains(option_list, _ENABLED)
    end

    # Add or remove minorversion=1 according to nfs41.
    # FIXME vfstype=nfs4 is deprecated in favor of nfsvers=4 (aka vers=4)
    # @param [String] options fstab option string
    # @param [Boolean] nfs41   is version >= 4.1 enabled
    # @return        new fstab option string
    def set_nfs41(options, nfs41)
      # don't mutate the string unnecessarily
      return options if get_nfs41(options) == nfs41

      _ENABLED = "minorversion=1"
      _DISABLED = "minorversion=0"

      option_list = from_string(options)
      option_list = Builtins.filter(option_list) { |opt| opt != _ENABLED }
      option_list = Builtins.filter(option_list) { |opt| opt != _DISABLED }

      option_list = Builtins.add(option_list, _ENABLED) if nfs41

      to_string(option_list)
    end

    publish :function => :validate, :type => "string (string)"
    publish :function => :get_nfs41, :type => "boolean (string)"
    publish :function => :set_nfs41, :type => "string (string, boolean)"
  end

  NfsOptions = NfsOptionsClass.new
  NfsOptions.main
end
