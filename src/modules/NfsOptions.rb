require "yast"
require "y2storage/filesystems/nfs_version"
require "y2storage/filesystems/nfs_options"

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
    # - systemd options:
    #   https://www.freedesktop.org/software/systemd/man/systemd.mount.html
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
      "sync",
      "x-initrd.mount",
      "x-systemd.automount",
      "x-systemd.device-bound",
      "x-systemd.growfs",
      "x-systemd.makefs",
      "x-systemd.rw-only"
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
      "wsize",
      "x-systemd.after",
      "x-systemd.before",
      "x-systemd.device-timeout",
      "x-systemd.idle-timeout",
      "x-systemd.mount-timeout",
      "x-systemd.required-by",
      "x-systemd.requires",
      "x-systemd.requires-mounts-for",
      "x-systemd.wanted-by"
    ].freeze

    def main
      textdomain "nfs"
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

      nfs_options = Y2Storage::Filesystems::NfsOptions.create_from_fstab(options)

      nfs_options.options.each do |opt|
        key, value, *rest = opt.split("=")

        # Known options without any expected value
        if non_value_option?(key)
          next if value.nil?

          # To translators: error popup
          error_message = format(_("Unexpected value '%{value}' for option '%{key}'"), value: value, key: key)
        # All unknown options
        elsif !OPTIONS_WITH_VALUE.include?(key)
          # To translators: error popup
          error_message = format(_("Unknown option: '%{key}'"), key: key)
        # All known ones with badly specified values
        elsif !rest.empty?
          # To translators: error popup
          error_message = format(_("Invalid option: '%{opt}'"), opt: opt)
        # All options missing a value
        elsif value.nil?
          # To translators: error popup
          error_message = format(_("Empty value for option: '%{key}'"), key: key)
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
    # @return [Y2Storage::Filesystems::NfsVersion]
    def nfs_version(options)
      nfs_options = Y2Storage::Filesystems::NfsOptions.create_from_fstab(options)

      nfs_options.version
    end

    # Generates mount options with the changes needed to ensure the given NFS protocol version
    #
    # Although it can handle several wrong or legacy configurations, this method
    # will not work if the mount options string is malformed.
    #
    # @param options [String] mount options in the comma-separated format used
    #   by mount and /etc/fstab
    # @param version [Y2Storage::Filesystems::NfsVersion]
    #
    # @return [String]
    def set_nfs_version(options, version)
      nfs_options = Y2Storage::Filesystems::NfsOptions.create_from_fstab(options)

      nfs_options.version = version

      nfs_options.to_fstab
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
      nfs_version(options).value == "4.1"
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
      value = nfs41 ? "4.1" : "any"

      version = Y2Storage::Filesystems::NfsVersion.find_by_value(value)

      set_nfs_version(options, version)
    end

    publish function: :validate, type: "string (string)"
    publish function: :get_nfs41, type: "boolean (string)"
    publish function: :set_nfs41, type: "string (string, boolean)"
  end

  NfsOptions = NfsOptionsClass.new
  NfsOptions.main
end
