# encoding: utf-8

require "yast"

# YaST namespace
module Yast
  # Handle NFS mount options
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
      "diratime",
      "exec",
      "fg",
      "fsc",
      "group",
      "hard",
      "intr",
      "iversion",
      "lock",
      "mand",
      "owner",
      "posix",
      "rdirplus",
      "relatime",
      "soft",
      "strictatime",
      "suid",
      "tcp",
      "udp",
      "user",
      "users"
    ]

    NEGATED_OPTIONS = NEGATABLE_OPTIONS.map { |o| "no#{o}" }

    # these cannot be negated
    # they are not nfs specific BTW
    SIMPLE_OPTIONS = [
      "_netdev",
      "async",
      "bind",
      "defaults",
      "dirsync",
      "loud",
      "nofail",
      "owner",
      "rbind",
      "remount",
      "ro",
      "rw",
      "silent",
      "sync"
    ]

    OPTIONS_WITH_VALUE = [
      "acdirmax",
      "acdirmin",
      "acdirmin",
      "acregmax",
      "acregmin",
      "actimeo",
      "bsize",
      "clientaddr",
      "context",
      "defcontext",
      "fscontext",
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
      "rootcontext",
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

    def non_value_option?(option)
      NEGATABLE_OPTIONS.include?(option) || NEGATED_OPTIONS.include?(option) || SIMPLE_OPTIONS.include?(option)
    end

    # Checks the nfs options for /etc/fstab:
    # nonempty, comma separated list of foo,nofoo,bar=baz (see nfs(5))
    # @param [String] options   options
    # @return         a translated string with error message, emtpy string if ok
    def validate(options)
      # To translators: error popup
      return _("Empty option strings are not allowed.") if options.empty?

      error_message = ""

      from_string(options).each do |opt|
        key, value, *rest = opt.split("=")

        # Known options without any expected value
        if non_value_option?(key)
          next if value.nil?
          # To translators: error popup
          error_message = _("Unexpected value '%{value}' for option '%{key}'") % { :value => value, :key => key }
        # All unknown options
        elsif !OPTIONS_WITH_VALUE.include?(key)
          # To translators: error popup
          error_message = _("Unknown option: '%{key}'") % { :key => key }
        # All known ones with badly specified values
        elsif !rest.empty?
          # To translators: error popup
          error_message = _("Invalid option: '%{opt}'") % { :opt => opt }
        # All options missing a value
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

      enabled = "minorversion=1"
      Builtins.contains(option_list, enabled)
    end

    # Add or remove minorversion=1 according to nfs41.
    # FIXME: vfstype=nfs4 is deprecated in favor of nfsvers=4 (aka vers=4)
    # @param [String] options fstab option string
    # @param [Boolean] nfs41   is version >= 4.1 enabled
    # @return        new fstab option string
    def set_nfs41(options, nfs41)
      # don't mutate the string unnecessarily
      return options if get_nfs41(options) == nfs41

      enabled  = "minorversion=1"
      disabled = "minorversion=0"

      option_list = from_string(options)
      option_list = Builtins.filter(option_list) { |opt| opt != enabled }
      option_list = Builtins.filter(option_list) { |opt| opt != disabled }

      option_list = Builtins.add(option_list, enabled) if nfs41

      to_string(option_list)
    end

    publish :function => :validate, :type => "string (string)"
    publish :function => :get_nfs41, :type => "boolean (string)"
    publish :function => :set_nfs41, :type => "string (string, boolean)"
  end

  NfsOptions = NfsOptionsClass.new
  NfsOptions.main
end
