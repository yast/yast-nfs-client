# encoding: utf-8

require "yast"
require "y2nfs_client/nfs_version"

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
    ].freeze

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
    ].freeze

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
      # Minorversion is basically undocumented and obsolete (nfsvers supports
      # strings line "4.1"). Commented out so it gets deleted.
      # "minorversion",
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
    ].freeze

    def main
      textdomain "nfs"
    end

    # Parse to an internal representation:
    # Simply split by commas, but "defaults" is represented by the empty list
    # @param [String] options a fstab option string
    # @return [Array<String>] of individual options
    def from_string(options)
      return [] if options == "defaults"

      options.split(",")
    end

    # Convert list of individual options to a fstab option string
    # @param [Array<String>] option_list list of individual options
    # @return [String] a fstab option string
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
    # @return [String] a translated string with an error message, emtpy if OK
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
          error_message = _("Unexpected value '%{value}' for option '%{key}'") % { value: value, key: key }
        # All unknown options
        elsif !OPTIONS_WITH_VALUE.include?(key)
          # To translators: error popup
          error_message = _("Unknown option: '%{key}'") % { key: key }
        # All known ones with badly specified values
        elsif !rest.empty?
          # To translators: error popup
          error_message = _("Invalid option: '%{opt}'") % { opt: opt }
        # All options missing a value
        elsif value.nil?
          # To translators: error popup
          error_message = _("Empty value for option: '%{key}'") % { key: key }
        end

        break unless error_message.empty?
      end

      error_message
    end

    # Version of the NFS protocol specified in a given set of mount options.
    #
    # This method can handle situations in which 'nfsvers' and 'vers' (the two
    # equivalent options to specify the protocol) are used more than once (which
    # is wrong but recoverable), but if will not work if the mount options
    # string is malformed.
    #
    # @param options [String] mount options in the comma-separated format used
    #   by mount and /etc/fstab
    # @return [Y2NfsClient::NfsVersion]
    def nfs_version(options)
      option_list = from_string(options)
      Y2NfsClient::NfsVersion.for_mntops_value(relevant_version_value(option_list))
    end

    # Returns a copy of the mount options with the changes needed to ensure the
    # given NFS protocol version.
    #
    # This method modifies or deletes the existing 'nfsvers' or 'vers' option
    # (deleting always the surplus options). If no option is present and one
    # must be added, 'nfsvers' is used.
    #
    # Although it can handle several wrong or legacy configurations, this method
    # will not work if the mount options string is malformed.
    #
    # @param options [String] mount options in the comma-separated format used
    #   by mount and /etc/fstab
    # @param version [Y2NfsClient::NfsVersion]
    def set_nfs_version(options, version)
      option_list = from_string(options)
      without_option = version.mntops_value.nil?

      # Cleanup minorversion, it should never be used
      option_list.delete_if { |opt| opt.start_with?("minorversion=") }

      # Cleanup surplus options
      option_to_keep = without_option ? nil : relevant_version_option(option_list)
      option_list.delete_if { |opt| version_option?(opt) && !opt.equal?(option_to_keep) }

      return to_string(option_list) if without_option

      if option_to_keep
        option_to_keep.gsub!(/=.*$/, "=#{version.mntops_value}")
      else
        option_list << "nfsvers=#{version.mntops_value}"
      end

      to_string(option_list)
    end

    # Whether the given mount options correspond to a NFSv4.1 mount
    #
    # This checks the usage of 'nfsvers' and 'vers'. 'minorversion' is ignored
    # since it should not be used nowadays.
    #
    # @param options [String] mount options in the comma-separated format used
    #   by mount and /etc/fstab
    # @return [Boolean] is version >= 4.1 enabled
    def get_nfs41(options)
      nfs_version(options).mntops_value == "4.1"
    end

    # Modifies the mount options to make sure NFSv4.1 is used (or to make sure
    # it stops being used).
    #
    # This uses 'nfsvers' (or 'vers' if it was already present). Any
    # 'minorversion' option will be deleted, since they should not be longer
    # used.
    #
    # @param options [String] mount options in the comma-separated format used
    #   by mount and /etc/fstab
    # @param nfs41 [Boolean] whether to enable version >= 4.1. If false the
    #   options will be configured to use any NFS version.
    # @return [String] new fstab option string
    def set_nfs41(options, nfs41)
      version_string = nfs41 ? "4.1" : nil
      version = Y2NfsClient::NfsVersion.for_mntops_value(version_string)
      set_nfs_version(options, version)
    end

    # Checks whether some of the old options that used to work to configure
    # the NFS version (but do not longer work now) is used.
    #
    # Basically, this checks for the presence of minorversion
    #
    # @param options [String] mount options in the comma-separated format used
    #   by mount and /etc/fstab
    # @return [Boolean]
    def legacy?(options)
      option_list = from_string(options)
      option_list.any? { |opt| opt.start_with?("minorversion=") }
    end

    publish function: :validate, type: "string (string)"
    publish function: :get_nfs41, type: "boolean (string)"
    publish function: :set_nfs41, type: "string (string, boolean)"

  private

    # Option used to set the NFS protocol version
    #
    # @param option_list [Array<String>]
    # @return [String, nil] contains the whole 'option=value' string
    def relevant_version_option(option_list)
      # According to manual tests and documentation, none of the forms has higher precedence.
      # Use #reverse_each because in case of conflicting options, the latest one is used by mount
      option_list.reverse_each.find do |opt|
        version_option?(opt)
      end
    end

    # Value part for {#relevant_version_option}
    #
    # @param option_list [Array<String>]
    # @return [String, nil]
    def relevant_version_value(option_list)
      relevant_option = relevant_version_option(option_list)
      return nil unless relevant_option
      parts = relevant_option.split("=")
      return nil if parts.size == 1
      parts.last
    end

    # Checks if a given option is used to configure the NFS protocol version
    #
    # @param [String]
    # @return [Boolean]
    def version_option?(option)
      option.start_with?("nfsvers=", "vers=")
    end
  end

  NfsOptions = NfsOptionsClass.new
  NfsOptions.main
end
