# encoding: utf-8
#
# Copyright (c) [2018] SUSE LLC
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

require "yast"

module Y2NfsClient
  # Version of the NFS protocol configured for an NFS mount
  #
  # The main goal of the class if to map how the version is configured in the
  # /etc/fstab entry with how that is presented to the user.
  #
  # Each instance is an immutable object that can represent the configuration
  # to enforce a concrete version or a more generic configuration (i.e. "use
  # any available version").
  class NfsVersion
    include Yast::I18n
    extend Yast::I18n
    textdomain "nfs"

    # Constructor
    def initialize(mntops_value, label, widget_id, widget_text)
      textdomain "nfs"

      @mntops_value = mntops_value
      @label = label
      @widget_id = widget_id
      @widget_text = widget_text
    end

    ALL = [
      new(nil,   N_("Any"),     :vers_any, N_("Any (Highest Available)")),
      new("3",   N_("NFSv3"),   :vers_3,   N_("Force NFSv3")),
      new("4",   N_("NFSv4"),   :vers_4,   N_("Force NFSv4")),
      new("4.1", N_("NFSv4.1"), :vers_4_1, N_("Force pNFS (v4.1)"))
    ].freeze
    private_constant :ALL

    # Sorted list of all possible settings
    def self.all
      ALL.dup
    end

    # An instance corresponding to a given value in the mount options
    #
    # @see #mntops_value
    #
    # @param value [String]
    # @return [NfsVersion]
    def self.for_mntops_value(value)
      value = "4" if value == "4.0"
      all.find { |version| version.mntops_value == value } or raise "Unknown mntops value #{value.inspect}"
    end

    # Value used in the corresponding mount option (nfsvers or vers)
    #
    # @return [String]
    attr_reader :mntops_value

    # Id for a widget representing the instance
    #
    # @return [Symbol]
    attr_reader :widget_id

    # Short localized label to represent the instance in listings
    #
    # @return [String] very likely, a frozen string
    def label
      _(@label)
    end

    # Localized text to use in a widget representing the instance
    #
    # @return [String] very likely, a frozen string
    def widget_text
      _(@widget_text)
    end

    def ==(other)
      other.class == self.class && other.mntops_value == mntops_value
    end

    alias_method :eql?, :==

    # Whether the system infrastructure associated to NFSv4 (e.g. enabled
    # NFS4_SUPPORT in sysconfig/nfs) is needed in order to use this version of
    # the protocol.
    #
    # @return [Boolean]
    def requires_v4?
      return false if mntops_value.nil?
      mntops_value.start_with?("4")
    end

    # Whether is necessary to use the browsing mechanisms associated to NFSv4 in
    # order to find shares of this type in the network or in a given server.
    #
    # Scanning a network or server to find NFS shares is completely different
    # depending on the version of the protocol (version 3 vs version 4+).
    #
    # @return [Boolean]
    def browse_with_v4?
      requires_v4?
    end
  end
end
