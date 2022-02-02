# Copyright (c) [2022] SUSE LLC
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
require "y2storage/filesystems/nfs_version"

Yast.import "UI"

module Y2NfsClient
  module Widgets
    # Widget to select a NFS version
    class NfsVersion
      include Yast::UIShortcuts
      extend Yast::I18n
      include Yast::I18n

      textdomain "nfs"

      # Constructor
      #
      # @param initial_version [Y2Storage::Filesystems::NfsVersion]
      def initialize(initial_version)
        super()

        textdomain "nfs"

        @initial_version = initial_version
      end

      # @return [Yast::Term]
      def contents
        ComboBox(widget_id, _("NFS &Version"), items)
      end

      # Version currently selected in the widget
      #
      # @return [Y2Storage::Filesystems::NfsVersion]
      def value
        value = Yast::UI.QueryWidget(widget_id, :Value)

        Y2Storage::Filesystems::NfsVersion.find_by_value(value)
      end

    private

      # @return [Y2Storage::Filesystems::NfsVersion]
      attr_reader :initial_version

      # @return [Yast::Term]
      def widget_id
        Id(:nfs_version)
      end

      # @return [Array<Yast::Term>]
      def items
        Y2Storage::Filesystems::NfsVersion.all.map { |v| generate_item(v) }
      end

      # Generates a selection item from the given version
      #
      # @param version [Y2Storage::Filesystems::NfsVersion]
      # @return [Yast::Term]
      def generate_item(version)
        Item(Id(version.value), label_for(version), version == initial_version)
      end

      # Label for the given version
      #
      # @param version [Y2Storage::Filesystems::NfsVersion]
      # @return [String]
      def label_for(version)
        case version.value
        when "any"
          N_("Any (Highest Available)")
        when "3"
          N_("Force NFSv3")
        when "4"
          N_("Force NFSv4")
        when "4.1"
          N_("Force pNFS (v4.1)")
        when "4.2"
          N_("Force NFSv4.2")
        else
          version.value
        end
      end
    end
  end
end
