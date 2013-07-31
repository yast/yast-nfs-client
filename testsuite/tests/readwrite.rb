# encoding: utf-8

# Module:
#   NFS client configuration
#
# Summary:
#   Testsuite
#
# Authors:
#   Martin Vidner <mvidner@suse.cz>
#
# $Id$
module Yast
  class ReadwriteClient < Client
    def main
      # testedfiles: Nfs.ycp Service.ycp Report.ycp Testsuite.ycp

      Yast.include self, "testsuite.rb"

      @I_READ = { "target" => { "size" => 0 } }
      @I_WRITE = {}
      @I_EXEC = { "target" => { "bash_output" => {} } }
      TESTSUITE_INIT([@I_READ, @I_WRITE, @I_EXEC], nil)

      Yast.import "Nfs"
      Yast.import "Report"
      Yast.import "Progress"

      @progress_orig = Progress.set(false)
      Report.DisplayErrors(false, 0)

      @service_on = { "start" => ["3", "5"], "stop" => ["3", "5"] }
      @service_off = { "start" => [], "stop" => [] }
      @READ = {
        # Runlevel:
        "init"      => {
          "scripts" => {
            "exists"   => true,
            "runlevel" => {
              "portmap"        => @service_on,
              "nfs"            => @service_on,
              "nfsboot"        => @service_off,
              "network"        => @service_off,
              "networkmanager" => @service_on
            },
            # their contents is not important for ServiceAdjust
            "comment"  => {
              "portmap" => {},
              "nfs"     => {}
            }
          }
        },
        # 	// targetpkg:
        # 	"targetpkg": $[
        # 	    // autofs
        # 	    "installed": true,
        # 	    ],
        # Nis itself:
        "etc"       => {
          "fstab"       => [
            {
              "file"    => "/",
              "freq"    => 1,
              "mntops"  => "defaults",
              "passno"  => 2,
              "spec"    => "/dev/hda6",
              "vfstype" => "reiserfs"
            },
            {
              "file"    => "/home",
              "freq"    => 0,
              "mntops"  => "defaults",
              "passno"  => 0,
              "spec"    => "foo.bar.com:/home",
              "vfstype" => "nfs"
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
              "file"    => "/a\\040space",
              "freq"    => 1,
              "mntops"  => "defaults",
              "passno"  => 3,
              "spec"    => "/dev/hda7",
              "vfstype" => "reiserfs"
            },
            {
              "file"    => "/b\\040space",
              "freq"    => 0,
              "mntops"  => "defaults",
              "passno"  => 0,
              "spec"    => "foo.bar.com:/space\\040dir",
              "vfstype" => "nfs"
            }
          ],
          "idmapd_conf" => "localhost"
        },
        "sysconfig" => {
          "nfs" => { "NFS4_SUPPORT" => "yes", "NFS_SECURITY_GSS" => "yes" }
        },
        "target"    => { "stat" => { "dummy" => true } }
      }

      @WRITE = {}

      @WRITE_KO = { "etc" => { "fstab" => false } }

      @EXECUTE = {
        "target" => {
          "bash_output" => { "exit" => 0, "stdout" => "", "stderr" => "" },
          "mkdir"       => true
        }
      }

      DUMP("Read")
      TEST(lambda { Nfs.Read }, [@READ, @WRITE, @EXECUTE], nil)
      DUMP("Write OK")
      TEST(lambda { Nfs.Write }, [@READ, @WRITE, @EXECUTE], nil)
      DUMP("Write KO")
      TEST(lambda { Nfs.Write }, [@READ, @WRITE_KO, @EXECUTE], nil)

      nil
    end
  end
end

Yast::ReadwriteClient.new.main
