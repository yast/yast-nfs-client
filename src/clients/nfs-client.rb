# encoding: utf-8

# Author:	Martin Vidner <mvidner@suse.cz>
# Summary:	Just a redirection
# $Id$
module Yast
  class NfsClientClient < Client
    def main
      @target = "nfs"
      WFM.CallFunction(@target, WFM.Args)
    end
  end
end

Yast::NfsClientClient.new.main
