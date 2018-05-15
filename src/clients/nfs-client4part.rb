# encoding: utf-8

# YaST namespace
module Yast
  # nfs-client stuff made accesible from the partitioner
  class NfsClient4partClient < Client
    def main
      Yast.import "UI"
      textdomain "nfs"

      Yast.import "Nfs"
      Yast.import "Wizard"
      Yast.include self, "nfs/ui.rb"
      Yast.include self, "nfs/routines.rb"

      # y2milestone("----------------------------------------");
      # y2milestone("Nfs client proposal started");
      # y2milestone("Arguments: %1", WFM::Args());

      @ret = nil
      @func = ""
      @param = {}

      if Ops.greater_than(Builtins.size(WFM.Args), 0) &&
          Ops.is_string?(WFM.Args(0))
        @func = Convert.to_string(WFM.Args(0))
        if Ops.greater_than(Builtins.size(WFM.Args), 1) &&
            Ops.is_map?(WFM.Args(1))
          @param = Convert.to_map(WFM.Args(1))
        end
      end

      if @func == "CreateUI"
        Wizard.SetHelpText(@help_text1)
        return FstabTab()
      elsif @func == "FromStorage"
        shares = Ops.get_list(@param, "shares", [])
        @nfs_entries = Nfs.load_nfs_entries(shares)
      elsif @func == "Read"
        Nfs.skip_fstab = true
        Nfs.Read
      elsif @func == "HandleEvent"
        @widget_id = Ops.get(@param, "widget_id")
        @w_ids = [:newbut, :editbut, :delbut]

        HandleEvent(@widget_id)
        Builtins.y2milestone("%1", @modify_line)
        Nfs.nfs_entries = deep_copy(@nfs_entries)

        if Builtins.contains(@w_ids, Convert.to_symbol(@widget_id))
          return fstab_to_storage(@modify_line)
        end
      end

      nil
    end
  end
end

Yast::NfsClient4partClient.new.main
