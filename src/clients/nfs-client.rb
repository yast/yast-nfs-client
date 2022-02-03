# YaST namespace
module Yast
  # Just a redirection
  class NfsClientClient < Client
    def main
      @target = "nfs"
      WFM.CallFunction(@target, WFM.Args)
    end
  end
end

Yast::NfsClientClient.new.main
