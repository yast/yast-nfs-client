# encoding: utf-8

module Yast
  class AutoyastClient < Client
    def main
      Yast.include self, "testsuite.rb"
      @I_READ = { "target" => { "tmpdir" => "/tmp" } }
      @I_WRITE = {}
      @I_EXEC = {}
      TESTSUITE_INIT([@I_READ, @I_WRITE, @I_EXEC], nil)

      @READ = {
        "etc"       => { "idmapd_conf" => "localdomain" },
        "sysconfig" => {
          "nfs" => { "NFS4_SUPPORT" => "no", "NFS_SECURITY_GSS" => "no" }
        }
      }

      Yast.import "Nfs"
      Yast.import "Assert"

      DUMP("Nfs::Import")
      # ---------
      DUMP("- basic, SLE11-SP2")
      @entry1 = {
        "server_path" => "data.example.com:/mirror",
        "mount_point" => "/mirror",
        "nfs_options" => "defaults"
      }

      TEST(lambda { Nfs.ImportAny([@entry1]) }, [@READ, {}, {}], nil)
      Assert.Equal(1, Builtins.size(Nfs.nfs_entries))
      Assert.Equal(
        "data.example.com:/mirror",
        Ops.get_string(Nfs.nfs_entries, [0, "spec"], "")
      )

      DUMP("-- and Export")
      @ex = Nfs.Export
      @e = Ops.get_list(@ex, "nfs_entries", [])
      Assert.Equal(1, Builtins.size(@e))
      Assert.Equal(true, Builtins.haskey(@ex, "enable_nfs4"))
      Assert.Equal(true, Builtins.haskey(@ex, "idmapd_domain"))
      Assert.Equal(
        "data.example.com:/mirror",
        Ops.get_string(@e, [0, "server_path"], "")
      )
      Assert.Equal("/mirror", Ops.get_string(@e, [0, "mount_point"], ""))
      Assert.Equal("defaults", Ops.get_string(@e, [0, "nfs_options"], ""))

      # ---------
      DUMP("- empty")
      TEST(lambda { Nfs.ImportAny([]) }, [@READ, {}, {}], nil)
      Assert.Equal(0, Builtins.size(Nfs.nfs_entries))

      # ---------
      DUMP("- invalid, missing basic data")
      @entry_invalid = { "server_path" => "data.example.com:/mirror" }

      Nfs.ImportAny([@entry_invalid])
      Assert.Equal(0, Builtins.size(Nfs.nfs_entries))

      # ---------
      DUMP("- basic, SLE11-SP3")
      @global_options = {
        "enable_nfs4"   => true,
        "idmapd_domain" => "example.com"
      }
      TEST(lambda { Nfs.ImportAny([@global_options, @entry1]) }, [@READ, {}, {}], nil)
      Assert.Equal(true, Nfs.nfs4_enabled)
      Assert.Equal("example.com", Nfs.idmapd_domain)
      Assert.Equal(1, Builtins.size(Nfs.nfs_entries))
      Assert.Equal(
        "data.example.com:/mirror",
        Ops.get_string(Nfs.nfs_entries, [0, "spec"], "")
      )

      DUMP("-- and Export")
      @ex = Nfs.Export
      @e = Ops.get_list(@ex, "nfs_entries", [])
      Assert.Equal(1, Builtins.size(@e))
      Assert.Equal(true, Ops.get_boolean(@ex, "enable_nfs4", false))
      Assert.Equal("example.com", Ops.get_string(@ex, "idmapd_domain", ""))
      Assert.Equal(
        "data.example.com:/mirror",
        Ops.get_string(@e, [0, "server_path"], "")
      )
      Assert.Equal("/mirror", Ops.get_string(@e, [0, "mount_point"], ""))
      Assert.Equal("defaults", Ops.get_string(@e, [0, "nfs_options"], ""))

      # ---------
      DUMP("- NFSv4 via vfstype")
      @global_options2 = { "idmapd_domain" => "example.com" }
      @entry2 = {
        "server_path" => "data.example.com:/mirror",
        "mount_point" => "/mirror",
        "nfs_options" => "defaults",
        "vfstype"     => "nfs4"
      }

      TEST(lambda { Nfs.ImportAny([@global_options2, @entry2]) }, [@READ, {}, {}], nil)

      Assert.Equal(true, Nfs.nfs4_enabled)
      Assert.Equal("example.com", Nfs.idmapd_domain)
      Assert.Equal(1, Builtins.size(Nfs.nfs_entries))
      Assert.Equal(
        "data.example.com:/mirror",
        Ops.get_string(Nfs.nfs_entries, [0, "spec"], "")
      )

      DUMP("-- and Export")
      @ex = Nfs.Export
      @e = Ops.get_list(@ex, "nfs_entries", [])
      Assert.Equal(1, Builtins.size(@e))
      Assert.Equal(true, Ops.get_boolean(@ex, "enable_nfs4", false))
      Assert.Equal("example.com", Ops.get_string(@ex, "idmapd_domain", ""))
      Assert.Equal(
        "data.example.com:/mirror",
        Ops.get_string(@e, [0, "server_path"], "")
      )
      Assert.Equal("/mirror", Ops.get_string(@e, [0, "mount_point"], ""))
      Assert.Equal("defaults", Ops.get_string(@e, [0, "nfs_options"], ""))

      # ---------
      DUMP("- with GSS")
      @global_options = {
        "enable_nfs4"    => true,
        "enable_nfs_gss" => true,
        "idmapd_domain"  => "example.com"
      }
      TEST(lambda { Nfs.ImportAny([@global_options, @entry1]) }, [@READ, {}, {}], nil)
      # assertions shortened
      Assert.Equal(true, Nfs.nfs_gss_enabled)
      Assert.Equal(1, Builtins.size(Nfs.nfs_entries))
      Assert.Equal(
        "data.example.com:/mirror",
        Ops.get_string(Nfs.nfs_entries, [0, "spec"], "")
      )

      DUMP("-- and Export")
      @ex = Nfs.Export
      @e = Ops.get_list(@ex, "nfs_entries", [])
      Assert.Equal(1, Builtins.size(@e))
      Assert.Equal(true, Ops.get_boolean(@ex, "enable_nfs_gss", false))
      Assert.Equal(
        "data.example.com:/mirror",
        Ops.get_string(@e, [0, "server_path"], "")
      )

      nil
    end
  end
end

Yast::AutoyastClient.new.main
