# encoding: utf-8

require "yast"

module Yast
  class NfsOptionsClass < Module
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
      # but not in nfs-utils.

      # these can be negated by "no"
      NEGATABLE_OPTIONS = [
        "ac",
        "acl",
        "atime",
        "auto",
        "bg",
        "cto",
        "dev",
        "exec",
        "fg",
        "group",
        "hard",
        "intr",
        "lock",
        "owner",
        "posix",
        "rdirplus",
        "soft",
        "suid",
        "tcp",
        "udp",
        "user",
        "users"
      ]

      NEGATED_OPTIONS = NEGATABLE_OPTIONS.map{ |o| "no#{o}" }

      # these cannot be negated
      # they are not nfs specific BTW
      SIMPLE_OPTIONS = [
        "_netdev",
        "async",
        "bind",
        "defaults",
        "dirsync",
        "rbind",
        "remount",
        "ro",
        "rw",
        "sync"
      ]

      OPTIONS_WITH_VALUE = [
        "acdirmax",
        "acdirmin",
        "acdirmin",
        "acregmax",
        "acregmin",
        "actimeo",
        "clientaddr",
        "minorversion",
        "mounthost",
        "mountport",
        "mountprog",
        "mountvers",
        "namlen",
        "nfsprog",
        "nfsvers",
        "port",
        "proto",
        "retrans",
        "retry",
        "rsize",
        "sec",
        "timeo",
        "vers",
        "wsize"
      ]

    def main
      textdomain "nfs"
    end

    # Parse to an internal representation:
    # Simply split by commas, but "defaults" is represented by the empty list
    # @param [String] options a fstab option string
    # @return [Array] of individual options
    def from_string(options)
      return [] if options == "defaults"

      options.split(",")
    end

    # Convert list of individual options to a fstab option string
    # @param [Array<String>] option_list list of individual options
    # @return a fstab option string
    def to_string(option_list)
      return "defaults" if option_list.empty?

      option_list.join(",")
    end

    # Checks the nfs options for /etc/fstab:
    # nonempty, comma separated list of foo,nofoo,bar=baz (see nfs(5))
    # @param [String] options   options
    # @return          a translated string with error message, emtpy string if ok
    def validate(options)
      # To translators: error popup
      if options.empty?
        return _("Empty option strings are not allowed.")
      end

      option_list = from_string(options)

      # first fiter out non value options and its nooptions forms (see nfs(5))
      option_list.reject!{ |o| NEGATABLE_OPTIONS.include?(o) }
      option_list.reject!{ |o| NEGATED_OPTIONS.include?(o) }
      option_list.reject!{ |o| SIMPLE_OPTIONS.include?(o) }

      error_message = ""
      option_list.each do |opt|
        key_value = opt.split("=")
        key, value = key_value
        # By now we have filtered out known options without values;
        # so what is left is either unknown options, ...
        # FIXME: this also triggers for "intr=bogus"
        # because we should have considered '=' before the simple options
        if ! OPTIONS_WITH_VALUE.include?(key)
          # To translators: error popup
          error_message = _("Unknown option: '%{key}'") % { :key => key }
        # ... or known ones with badly specified values
        elsif key_value.size > 2
          # To translators: error popup
          error_message = _("Invalid option: '%{opt}'") % { :opt => opt }
        elsif value.nil?
          # To translators: error popup
          error_message = _("Empty value for option: '%{key}'") % { :key => key }
        end
        break unless error_message.empty?
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
