# encoding: utf-8

module Yast
  class NfsOptionsClient < Client
    def main
      Yast.include self, "testsuite.rb"
      Yast.import "NfsOptions"
      Yast.import "Assert"

      DUMP("NfsOptions::validate")
      TEST(lambda { NfsOptions.validate("") }, [], nil)
      TEST(lambda { NfsOptions.validate("defaults") }, [], nil)
      TEST(lambda { NfsOptions.validate("nolock,bg") }, [], nil)
      TEST(lambda { NfsOptions.validate("nolock,nobg") }, [], nil)
      TEST(lambda { NfsOptions.validate("nolock,rsize=8192") }, [], nil)
      TEST(lambda { NfsOptions.validate("nolock, bg") }, [], nil)
      TEST(lambda { NfsOptions.validate("nolock,unknownoption") }, [], nil)
      TEST(lambda { NfsOptions.validate("nolock,unknownassignment=true") }, [], nil)
      TEST(lambda { NfsOptions.validate("nolock,rsize=") }, [], nil)
      TEST(lambda { NfsOptions.validate("nolock,two=equal=signs") }, [], nil)
      TEST(lambda { NfsOptions.validate("nolock,retrans=trans=trans") }, [], nil)
      TEST(lambda { NfsOptions.validate("nolock,intr=bogus") }, [], nil)

      DUMP("NfsOptions::get_nfs41")
      Assert.Equal(false, NfsOptions.get_nfs41(""))
      Assert.Equal(false, NfsOptions.get_nfs41("defaults"))
      Assert.Equal(false, NfsOptions.get_nfs41("ro,sync"))
      Assert.Equal(false, NfsOptions.get_nfs41("minorversion=0"))
      Assert.Equal(true, NfsOptions.get_nfs41("minorversion=1"))
      # "minorversion=2" does not exist yet, YAGNI
      Assert.Equal(false, NfsOptions.get_nfs41("subminorversion=1")) # substring must not match
      # Assert::Equal(?,  NfsOptions::get_nfs41("minorversion=1,minorversion=0")); // don't care
      Assert.Equal(false, NfsOptions.get_nfs41("ro,minorversion=0,sync"))
      Assert.Equal(true, NfsOptions.get_nfs41("ro,minorversion=1,sync"))

      DUMP("NfsOptions::set_nfs41")
      Assert.Equal("", NfsOptions.set_nfs41("", false))
      Assert.Equal("minorversion=1", NfsOptions.set_nfs41("", true))

      Assert.Equal("defaults", NfsOptions.set_nfs41("defaults", false))
      Assert.Equal("minorversion=1", NfsOptions.set_nfs41("defaults", true))

      Assert.Equal("ro,sync", NfsOptions.set_nfs41("ro,sync", false))
      Assert.Equal(
        "ro,sync,minorversion=1",
        NfsOptions.set_nfs41("ro,sync", true)
      )

      Assert.Equal(
        "minorversion=0",
        NfsOptions.set_nfs41("minorversion=0", false)
      )
      Assert.Equal(
        "minorversion=1",
        NfsOptions.set_nfs41("minorversion=0", true)
      )

      Assert.Equal("defaults", NfsOptions.set_nfs41("minorversion=1", false))
      Assert.Equal(
        "minorversion=1",
        NfsOptions.set_nfs41("minorversion=1", true)
      )

      Assert.Equal(
        "subminorversion=1",
        NfsOptions.set_nfs41("subminorversion=1", false)
      )
      Assert.Equal(
        "subminorversion=1,minorversion=1",
        NfsOptions.set_nfs41("subminorversion=1", true)
      )

      Assert.Equal(
        "ro,minorversion=0,sync",
        NfsOptions.set_nfs41("ro,minorversion=0,sync", false)
      )
      Assert.Equal(
        "ro,sync,minorversion=1",
        NfsOptions.set_nfs41("ro,minorversion=0,sync", true)
      )

      Assert.Equal(
        "ro,sync",
        NfsOptions.set_nfs41("ro,minorversion=1,sync", false)
      )
      Assert.Equal(
        "ro,minorversion=1,sync",
        NfsOptions.set_nfs41("ro,minorversion=1,sync", true)
      )

      nil
    end
  end
end

Yast::NfsOptionsClient.new.main
