# YaST namespace
module Yast
  # Client for autoinstallation
  class NfsAutoClient < Client
    def main
      Yast.import "UI"
      textdomain "nfs"

      Builtins.y2milestone("----------------------------------------")
      Builtins.y2milestone("Nfs auto started")

      Yast.import "Nfs"
      Yast.import "Wizard"
      Yast.include self, "nfs/ui.rb"

      @ret = nil
      @func = ""
      @param = {}

      # Check arguments
      if Ops.greater_than(Builtins.size(WFM.Args), 0) &&
          Ops.is_string?(WFM.Args(0))
        @func = Convert.to_string(WFM.Args(0))
        if Ops.greater_than(Builtins.size(WFM.Args), 1) &&
            Ops.is_map?(WFM.Args(1))
          @param = Convert.convert(
            WFM.Args(1),
            from: "any",
            to:   "map <string, any>"
          )
        end
        if Ops.greater_than(Builtins.size(WFM.Args), 1) &&
            Ops.is_list?(WFM.Args(1))
          Builtins.y2warning(
            "Old-style configuration detected (got list, expected map). " \
            "<nfs> section needs to be converted to match up-to-date schema"
          )
        end
      end
      Builtins.y2debug("func=%1", @func)
      Builtins.y2debug("param=%1", @param)

      # Create a summary
      case @func
      when "Import"
        @ret = Nfs.Import(@param)
      # Create a summary
      when "Summary"
        @ret = Nfs.Summary
      # Reset configuration
      when "Reset"
        Nfs.Import({})
        @ret = {}
      # Change configuration (run AutoSequence)
      when "Change"
        Wizard.CreateDialog
        Wizard.SetDesktopIcon("org.opensuse.yast.NFS")
        @ret = FstabDialog()
        UI.CloseDialog
      when "GetModified"
        @ret = Nfs.GetModified
      when "SetModified"
        Nfs.SetModified
      # Return actual state
      when "Packages"
        @ret = Nfs.AutoPackages
      # Return actual state
      when "Export"
        @ret = Nfs.Export
      when "Read"
        @ret = Nfs.Read
      # Write givven settings
      when "Write"
        Yast.import "Progress"
        @progress_orig = Progress.set(false)
        @ret = Nfs.WriteOnly
        Progress.set(@progress_orig)
      else
        Builtins.y2error("Unknown function: %1", @func)
        @ret = false
      end

      Builtins.y2debug("ret=%1", @ret)
      Builtins.y2milestone("Nfs auto finished")
      Builtins.y2milestone("----------------------------------------")

      deep_copy(@ret)

      # EOF
    end
  end
end

Yast::NfsAutoClient.new.main
