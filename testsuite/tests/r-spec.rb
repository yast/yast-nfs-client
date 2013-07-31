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
  class RSpecClient < Client
    def main
      # testedfiles: routines.ycp Testsuite.ycp

      Yast.include self, "testsuite.rb"
      Yast.include self, "nfs/routines.rb"

      DUMP("SpecToServPath")
      TEST(lambda { SpecToServPath("big.foo.com:/share/data") }, [], nil)
      TEST(lambda { SpecToServPath("only.server.com:") }, [], nil)
      TEST(lambda { SpecToServPath("nocolon.only.server.com") }, [], nil)
      TEST(lambda { SpecToServPath(":/only/path") }, [], nil)
      TEST(lambda { SpecToServPath("/nocolon/only/path") }, [], nil)
      TEST(lambda { SpecToServPath("fe80::219:d1ff:feac:fd10:/path") }, [], nil)
      TEST(lambda { SpecToServPath("") }, [], nil)

      nil
    end
  end
end

Yast::RSpecClient.new.main
