# encoding: utf-8

# Module:
#   NFS client configuration
#
# Summary:
#   Routines testuite
#
# Authors:
#   Martin Vidner <mvidner@suse.cz>
#
# $Id$
module Yast
  class RStripClient < Client
    def main
      # testedfiles: routines.ycp Testsuite.ycp

      Yast.include self, "testsuite.rb"
      Yast.include self, "nfs/routines.rb"

      DUMP("StripExtraSlash")
      TEST(->() { StripExtraSlash("") }, [], nil)
      TEST(->() { StripExtraSlash("/") }, [], nil)
      TEST(->() { StripExtraSlash("/normal/path") }, [], nil)
      TEST(->() { StripExtraSlash("/trailing/slash/") }, [], nil)

      nil
    end
  end
end

Yast::RStripClient.new.main
