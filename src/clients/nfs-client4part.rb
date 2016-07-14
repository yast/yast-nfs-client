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
        @shares = Ops.get_list(@param, "shares", [])

        Nfs.nfs_entries = Builtins.maplist(@shares) do |entry|
          {
            "spec"    => Ops.get_string(entry, "device", ""),
            "file"    => Ops.get_string(entry, "mount", ""),
            "vfstype" => Ops.get_symbol(entry, "used_fs", :nfs) == :nfs ? "nfs" : "nfs4",
            "mntops"  => Ops.get_string(entry, "fstopt", "")
          }
        end
        Builtins.y2milestone(
          "Nfs shares imported from storage %1",
          Nfs.nfs_entries
        )
        @nfs_entries = deep_copy(Nfs.nfs_entries)
        InitFstabEntries()
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
          return ToStorage(@modify_line)
        end
      end

      nil
    end

    def ToStorage(entry)
      entry = deep_copy(entry)
      ret = {}

      if entry && entry != {}
        ret = {
          "device"  => Ops.get_string(entry, "spec", ""),
          "mount"   => Ops.get_string(entry, "file", ""),
          "fstopt"  => Ops.get_string(entry, "mntops", ""),
          "vfstype" => Ops.get_string(entry, "vfstype", "nfs")
        }
        if Builtins.haskey(entry, "old")
          ret = Builtins.add(
            ret,
            "old_device",
            Ops.get_string(entry, "old", "")
          )
        end
      end
      deep_copy(ret)
    end
  end
end

Yast::NfsClient4partClient.new.main
