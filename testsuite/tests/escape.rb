# encoding: utf-8

# Module:
#   NFS client configuration
#
# Summary:
#   Space escaping testuite
#
# Authors:
#   Martin Vidner <mvidner@suse.cz>
#
# $Id$
module Yast
  class EscapeClient < Client
    def main
      # testedfiles: Nfs.ycp Testsuite.ycp

      Yast.include self, "testsuite.rb"

      @READ = { "target" => { "size" => 0 } }
      @WRITE = {}
      @EXEC = { "target" => { "bash_output" => {} } }
      TESTSUITE_INIT([@READ, @WRITE, @EXEC], nil)

      Yast.import "Nfs"

      DUMP("Nfs::EscapeSpaces1 normative")
      TEST(->() { Nfs.EscapeSpaces1(nil) }, [], nil)
      TEST(->() { Nfs.EscapeSpaces1("") }, [], nil)
      TEST(->() { Nfs.EscapeSpaces1(" ") }, [], nil)
      TEST(->() { Nfs.EscapeSpaces1("  ") }, [], nil)
      TEST(->() { Nfs.EscapeSpaces1("nospaces") }, [], nil)
      TEST(->() { Nfs.EscapeSpaces1("one space") }, [], nil)
      TEST(->() { Nfs.EscapeSpaces1(" before, two,  after ") }, [], nil)

      DUMP("Nfs::EscapeSpaces1 informative")
      # weird characters
      # TEST cuts it off at the newline :(
      TEST(->() { Nfs.EscapeSpaces1("'\"\\\n") }, [], nil)
      # see how it works when applied multiple times
      TEST(->() { Nfs.EscapeSpaces1(Nfs.EscapeSpaces1(" ")) }, [], nil)


      DUMP("Nfs::UnescapeSpaces1 normative")
      TEST(->() { Nfs.UnescapeSpaces1(nil) }, [], nil)
      TEST(->() { Nfs.UnescapeSpaces1("") }, [], nil)
      TEST(->() { Nfs.UnescapeSpaces1("\\040") }, [], nil)
      TEST(->() { Nfs.UnescapeSpaces1("\\040\\040") }, [], nil)
      TEST(->() { Nfs.UnescapeSpaces1("nospaces") }, [], nil)
      TEST(->() { Nfs.UnescapeSpaces1("one\\040space") }, [], nil)
      TEST(lambda do
        Nfs.UnescapeSpaces1("\\040before,\\040two,\\040\\040after\\040")
      end, [], nil)

      DUMP("Nfs::UnescapeSpaces1 informative")
      TEST(->() { Nfs.UnescapeSpaces1("\\041\\") }, [], nil)
      # see how it works when applied multiple times
      TEST(->() { Nfs.UnescapeSpaces1(Nfs.UnescapeSpaces1("\\040")) }, [], nil)

      nil
    end
  end
end

Yast::EscapeClient.new.main
