# YaST namespace
module Yast
  # Wizards definitions
  module NfsWizardsInclude
    def initialize_nfs_wizards(include_target)
      Yast.import "UI"

      textdomain "nfs"

      Yast.import "Sequencer"
      Yast.import "Wizard"

      Yast.include include_target, "nfs/ui.rb"
    end

    # Configuration of NFS client
    # without Read and Write
    # @return sequence result
    def MainSequence
      FstabDialog()
    end

    # Whole configuration of NFS client
    # @return sequence result
    def NfsSequence
      aliases = {
        "read"  => [-> { ReadDialog() }, true],
        "main"  => -> { MainSequence() },
        "write" => [-> { WriteDialog() }, true]
      }

      sequence = {
        "ws_start" => "read",
        "read"     => { abort: :abort, next: "main" },
        "main"     => { abort: :abort, next: "write" },
        "write"    => { abort: :abort, next: :next }
      }

      Wizard.OpenOKDialog
      Wizard.SetDesktopTitleAndIcon("org.opensuse.yast.NFS")

      ret = Sequencer.Run(aliases, sequence)

      UI.CloseDialog
      deep_copy(ret)
    end
  end
end
