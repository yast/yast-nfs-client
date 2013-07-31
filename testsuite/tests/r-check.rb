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
  class RCheckClient < Client
    def main
      # testedfiles: routines.ycp Testsuite.ycp

      Yast.include self, "testsuite.rb"
      Yast.include self, "nfs/routines.rb"

      @OK_Name = "foo.bar.com.tw"
      @TooLongName = "123456789012345678901234567890123456789012345678901234567890"
      @IllegalName = "Something:wrong"
      @IPv4 = "192.168.10.1"
      @IPv4_invalid = "192.168.10:1"
      @IPv6 = "fe80::219:d1ff:feac:fd10"
      @IPv6_invalid = "fe80::219::fd10"
      @IPv6_brackets = "[::1]"
      @IPv6_brackets_invalid = "[::1"
      @IPv6_link_local_nb = "fe80::3%eth0"
      @IPv6_link_local_ib = "[fe80::3%eth0]"
      @IPv6_link_local_invalid = "[fe80::3%]"

      DUMP("check_options")
      TEST(lambda { check_options("") }, [], nil)
      TEST(lambda { check_options("defaults") }, [], nil)
      TEST(lambda { check_options("nolock,bg") }, [], nil)
      TEST(lambda { check_options("nolock,nobg") }, [], nil)
      TEST(lambda { check_options("nolock,rsize=8192") }, [], nil)
      TEST(lambda { check_options("nolock, bg") }, [], nil)
      TEST(lambda { check_options("nolock,unknownoption") }, [], nil)
      TEST(lambda { check_options("nolock,unknownassignment=true") }, [], nil)
      TEST(lambda { check_options("nolock,rsize=") }, [], nil)
      TEST(lambda { check_options("nolock,two=equal=signs") }, [], nil)

      DUMP("CheckHostName")
      TEST(lambda { CheckHostName(@OK_Name) }, [], nil)
      TEST(lambda { CheckHostName(@TooLongName) }, [], nil)
      TEST(lambda { CheckHostName(@IllegalName) }, [], nil)
      # Too long & illegal char
      TEST(lambda { CheckHostName(Ops.add(@TooLongName, "!")) }, [], nil)
      # check IPv? adresses
      TEST(lambda { CheckHostName(@IPv4) }, [], nil)
      TEST(lambda { CheckHostName(@IPv4_invalid) }, [], nil)
      TEST(lambda { CheckHostName(@IPv6) }, [], nil)
      TEST(lambda { CheckHostName(@IPv6_invalid) }, [], nil)
      TEST(lambda { CheckHostName(@IPv6_brackets) }, [], nil)
      TEST(lambda { CheckHostName(@IPv6_brackets_invalid) }, [], nil)
      TEST(lambda { CheckHostName(@IPv6_link_local_nb) }, [], nil)
      TEST(lambda { CheckHostName(@IPv6_link_local_ib) }, [], nil)
      TEST(lambda { CheckHostName(@IPv6_link_local_invalid) }, [], nil)

      DUMP("FormatHostnameForFstab")
      TEST(FormatHostnameForFstab("::1"), [], nil)
      TEST(FormatHostnameForFstab("[::1]"), [], nil)
      TEST(FormatHostnameForFstab("127.0.0.1"), [], nil)
      TEST(FormatHostnameForFstab("suse.de"), [], nil)

      nil
    end
  end
end

Yast::RCheckClient.new.main
