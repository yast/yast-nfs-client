# encoding: utf-8

# File:	include/nfs/wizards.ycp
# Package:	Configuration of nfs
# Summary:	Wizards definitions
# Authors:	Martin Vidner <mvidner@suse.cz>
#
# $Id$
module Yast
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
        "read"  => [lambda { ReadDialog() }, true],
        "main"  => lambda { MainSequence() },
        "write" => [lambda { WriteDialog() }, true]
      }

      sequence = {
        "ws_start" => "read",
        "read"     => { :abort => :abort, :next => "main" },
        "main"     => { :abort => :abort, :next => "write" },
        "write"    => { :abort => :abort, :next => :next }
      }

      Wizard.OpenOKDialog
      Wizard.SetDesktopTitleAndIcon("nfs")

      ret = Sequencer.Run(aliases, sequence)

      UI.CloseDialog
      deep_copy(ret)
    end
  end
end
