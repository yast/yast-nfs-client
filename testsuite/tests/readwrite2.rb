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

require_relative "test_helper.rb"

module Yast
  class Readwrite2Client < Client
    include TestHelper

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
            "runlevel" => { "portmap" => @service_on, "nfs" => @service_on },
            # their contents is not important for ServiceAdjust
            "comment"  => {
              "portmap" => {},
              "nfs"     => {}
            }
          }
        },
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
          "nfs" => { "NFS4_SUPPORT" => "no", "NFS_SECURITY_GSS" => "no" }
        },
        "target"    => { "stat" => { "dummy" => true } }
      }

      # services portmap & nfs are stopped.
      @READ3 = Builtins.eval(@READ)
      Ops.set(@READ3, ["init", "scripts", "runlevel", "portmap"], @service_off)
      Ops.set(@READ3, ["init", "scripts", "runlevel", "nfs"], @service_off)

      # no nfs file-systems in /etc/fstab
      @EMPTY = Builtins.eval(@READ)
      Ops.set(
        @EMPTY,
        ["etc", "fstab"],
        [
          {
            "file"    => "/",
            "freq"    => 1,
            "mntops"  => "defaults",
            "passno"  => 2,
            "spec"    => "/dev/hda6",
            "vfstype" => "ext3"
          }
        ]
      )

      # services portmap & nfs are stopped; and /etc/fstab contains no nfs imports
      @EMPTY3 = Builtins.eval(@READ3)
      Ops.set(
        @EMPTY3,
        ["etc", "fstab"],
        [
          {
            "file"    => "/",
            "freq"    => 1,
            "mntops"  => "defaults",
            "passno"  => 2,
            "spec"    => "/dev/hda6",
            "vfstype" => "ext3"
          }
        ]
      )

      @WRITE = {}

      @WRITE_KO = { "etc" => { "fstab" => false } }

      @EXECUTE = {
        "target" => {
          "bash_output" => { "exit" => 0, "stdout" => "", "stderr" => "" },
          "mkdir"       => true
        }
      }

      # Change fstab name for test environment
      Nfs.etc_fstab_name = FSTAB_NAME

      # Using run_test from test_helper.rb to set up a temporary fstab before
      # and dump it after each test
      #
      # fstab contains nfs mounts & services are running
      DUMP("\nRead  - nfs is in use & running\n")
      run_test(->() { Nfs.Read }, [@READ, @WRITE, @EXECUTE], nil)
      # fstab unchanged
      DUMP("\nWrite - nfs is in use - start services\n")
      run_test(->() { Nfs.Write }, [@READ, @WRITE, @EXECUTE], nil)

      # fstab contains nfs mounts & services are stopped:-(
      DUMP("\nRead  - nfs is in use & stopped\n")
      run_test(->() { Nfs.Read }, [@READ3, @WRITE, @EXECUTE], nil)
      # fstab unchanged - so, start services
      DUMP("\nWrite - nfs is in use - so, start services\n")
      run_test(->() { Nfs.Write }, [@READ3, @WRITE, @EXECUTE], nil)

      # fstab contains no nfs mounts, services are running
      DUMP("\nRead  - nfs not used & running\n")
      run_test(->() { Nfs.Read }, [@EMPTY, @WRITE, @EXECUTE], nil)
      # fstab unchanged - so, STOP services
      DUMP("\nWrite - nfs not used - so, stopping services\n")
      run_test(->() { Nfs.Write }, [@EMPTY, @WRITE, @EXECUTE], nil)

      # fstab contains no nfs mount, serives are stopped
      DUMP("\nRead  - nfs not used & services are stopped\n")
      run_test(->() { Nfs.Read }, [@EMPTY3, @WRITE, @EXECUTE], nil)
      # fstab unchanged - so, leave services stopped
      DUMP("\nWrite - nfs not used; leave services stopped\n")
      run_test(->() { Nfs.Write }, [@EMPTY3, @WRITE, @EXECUTE], nil)

      # // nfs and portmap are running
      #     DUMP ("\nRead  - services are running\n");
      #     run_test (``(Nfs::Read ()), [READ, WRITE, EXECUTE], nil);
      #     DUMP ("\nWrite - services will be stopped\n");
      #     // Stop services!
      # //    Nfs::start = false;
      #     // And Write
      #     run_test (``(Nfs::Write ()), [READ, WRITE, EXECUTE], nil);
      #
      #     // nfs and portmap are running
      #     DUMP ("\nRead  - services are running\n");
      #     run_test (``(Nfs::Read ()), [READ, WRITE, EXECUTE], nil);
      #     DUMP ("\nWrite - services are running\n");
      #     // Start services (nfsserver)
      # //    Nfs::start = true;
      #     // And Write
      #     run_test (``(Nfs::Write ()), [READ, WRITE, EXECUTE], nil);
      #
      #     // nfs and portmap are stopped
      #     DUMP ("\nRead  - services are stopped\n");
      #     run_test (``(Nfs::Read ()), [READ3, WRITE, EXECUTE], nil);
      #     DUMP ("\nWrite - services will be stopped\n");
      #     // Leave services stopped
      # //    Nfs::start = false;
      #     // And Write
      #     run_test (``(Nfs::Write ()), [READ3, WRITE, EXECUTE], nil);
      #
      #     // nfs and portmap are stopped
      #     DUMP ("\nRead  - services are stopped\n");
      #     run_test (``(Nfs::Read ()), [READ3, WRITE, EXECUTE], nil);
      #     DUMP ("\nWrite - services will be started\n");
      #     // Start services
      # //    Nfs::start = true;
      #     // And Write
      #     run_test (``(Nfs::Write ()), [READ3, WRITE, EXECUTE], nil);
      #
      #     DUMP ("\nEMPTY\n");
      #     run_test (``(Nfs::Read ()), [EMPTY, WRITE, EXECUTE], nil);
      #     run_test (``(Nfs::Write ()), [EMPTY, WRITE, EXECUTE], nil);

      nil
    end
  end
end

Yast::Readwrite2Client.new.main
