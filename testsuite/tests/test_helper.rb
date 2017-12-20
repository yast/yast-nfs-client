# Helper methods for NFS-Client tests
#
require "yast2/etc_fstab"

module TestHelper
  FSTAB_NAME = "tmp.fstab".freeze

  # Map hash target-map-like keys for an fstab entry to the keys the EtcFstab
  # class expects
  FSTAB_KEY_MAP =
    {
      "spec"    => :device,
      "file"    => :mount_point,
      "vfstype" => :fs_type,
      "mntops"  => :mount_opts,
      "freq"    => :dump_pass,
      "passno"  => :fsck_pass
    }.freeze

  # Wrapper around TEST from include/testsuite.rb to create the correct fstab
  # before the test and dump it afterwards.
  #
  def run_test(function, input, default)
    File.delete(FSTAB_NAME)
    fstab_desc = input[0]["etc"]["fstab"]
    create_fstab(FSTAB_NAME, fstab_desc)

    dump_fstab("before")
    TEST(function, input, default)
    dump_fstab("after")
  end

  def dump_fstab(msg)
    DUMP("#{FSTAB_NAME} #{msg}:")
    DUMPFILE(FSTAB_NAME)
  end

  # Convert a target-map-like hash to the kind of hash that EtcFstab::Entry
  # expects - see FSTAB_KEY_MAP above.
  #
  def to_fstab_hash(orig_hash)
    fstab_hash = {}
    orig_hash.each do |key, value|
      key = FSTAB_KEY_MAP[key]
      fstab_hash[key] = value unless key.nil?
    end
    fstab_hash
  end

  # Create an fstab from an fstab description formatted like the old storage's
  # target map.
  #
  # @param fstab_desc [Array<Hash>]
  #
  def create_fstab(filename, fstab_desc)
    return if fstab_desc.nil?

    fstab = EtcFstab.new
    fstab_desc.each do |desc|
      begin
        entry = fstab.create_entry(to_fstab_hash(desc))
        entry.sanity_check
        fstab.add_entry(entry)
      rescue EtcFstab::InvalidEntryError => err
        DUMP("#{err.class} #{err}: entry description:\n#{desc}")
      end
    end
    fstab.write(filename)
  end
end
