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
  class RFstabClient < Client
    def main
      # testedfiles: routines.ycp Testsuite.ycp

      Yast.include self, "testsuite.rb"
      Yast.include self, "nfs/routines.rb"

      @PathTooLong = "12345678901234567890123456789012345678901234567890123456789012345678901234567890"

      @nfs_entries = [
        {
          "file"    => "/home",
          "freq"    => 0,
          "mntops"  => "defaults",
          "passno"  => 0,
          "spec"    => "foo.bar.com:/home",
          "vfstype" => "nfs4"
        },
        {
          "file"    => "/var/spool/mail",
          "freq"    => 0,
          "mntops"  => "defaults",
          "passno"  => 0,
          "spec"    => "foo.bar.com:/var/spool/mail",
          "vfstype" => "nfs"
        },
        {
          "file"    => "/install",
          "freq"    => 0,
          "mntops"  => "hard,intr",
          "passno"  => 0,
          # different from "file" (for order tests)
          "spec"    => "foo.bar.com.tw:/local/install",
          "vfstype" => "nfs"
        }
      ]

      DUMP("FstabTableItems")
      TEST(lambda { FstabTableItems(@nfs_entries) }, [], nil)

      DUMP("IsMpInFstab")
      # MountPoint in fstab
      TEST(lambda { IsMpInFstab(@nfs_entries, "/home") }, [], nil)
      # MountPoint in fstab
      TEST(lambda { IsMpInFstab(@nfs_entries, "/install") }, [], nil)
      # MountPoint NOT in fstab
      TEST(lambda { IsMpInFstab(@nfs_entries, "/not/in/fstab") }, [], nil)

      DUMP("CheckPath")
      # Empty path
      TEST(lambda { CheckPath("") }, [], nil)
      # Path is too long (cca 80 chars)
      TEST(lambda { CheckPath(@PathTooLong) }, [], nil)
      # First slash is missing
      TEST(lambda { CheckPath("not/begins/with/slash") }, [], nil)
      # Too long with slash
      TEST(lambda { CheckPath(Ops.add("/", @PathTooLong)) }, [], nil)
      # Regular path
      TEST(lambda { CheckPath("/regular/path") }, [], nil)

      nil
    end
  end
end

Yast::RFstabClient.new.main
