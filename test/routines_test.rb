require_relative "spec_helper"

module Yast
  # just a wrapper class for the nfs/routines.rb
  class NfsRoutinesIncludeTesterClass < Module
    extend Yast::I18n

    def main
      Yast.include self, "nfs/routines.rb"
    end
  end
end

describe "Yast::NfsRoutinesInclude" do
  subject { Yast::NfsRoutinesIncludeTesterClass.new }
  let(:nfs_entries) do
    [
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
  end

  before do
    subject.main
  end

  describe "#SpecToServPath" do
    it "returns a couple term with the server and the exported path params" do
      term = subject.SpecToServPath("big.foo.com:/share/data")
      expect(term.value).to eql(:couple)
      expect(term.params).to eql(["big.foo.com", "/share/data"])
      term = subject.SpecToServPath("big.foo.com:")
      expect(term.params).to eql(["big.foo.com", ""])
      term = subject.SpecToServPath("big.foo.com")
      expect(term.params).to eql(["", "big.foo.com"])
    end
  end

  describe "#StripExtraSplash" do
    it "returns the striped path" do
      expect(subject.StripExtraSlash("")).to eql("")
      expect(subject.StripExtraSlash("/")).to eql("/")
      expect(subject.StripExtraSlash("/path")).to eql("/path")
      expect(subject.StripExtraSlash("/path/")).to eql("/path")
    end
  end

  describe "#FstabTableItems" do
    context "given a list of nfs fstab entries" do
      it "returns a list of ui table items" do
        items = subject.FstabTableItems(nfs_entries)

        expect(items.size).to eql(3)
        expect(items.first.params[1]).to eql("foo.bar.com ")
        expect(items.first.params[2]).to eql("/home ")
        expect(items.first.params[2]).to eql("/home ")
        expect(items.first.params[4]).to eql("Any (Please Check) ")
        expect(items.first.params[5]).to eql("defaults ")
      end
    end
  end

  describe "IsMpInFstab" do
    context "given a list of fstab nfs entries and an mount point" do
      before do
        allow(Yast::Report).to receive(:Error)
        allow(subject).to receive(:non_nfs_mount_paths).and_return([])
      end

      context "when the given mount point is present in fstab" do
        it "returns true" do
          expect(subject.IsMpInFstab(nfs_entries, "/home")).to eql(true)
          expect(subject.IsMpInFstab(nfs_entries, "/install")).to eql(true)
        end

        it "reports an error" do
          expect(Yast::Report).to receive(:Error).with(/fstab already contains/)
          subject.IsMpInFstab(nfs_entries, "/home")
        end
      end
      context "when the given mount point is not present in fstab" do
        it "returns false" do
          expect(subject.IsMpInFstab(nfs_entries, "/not/in/fstab")).to eql(false)
        end
      end
    end
  end

  describe "#CheckPath" do
    let(:path) { "a" * 68 }

    context "when the given path size is in the 1..69 range" do
      context "and begins with a slash" do
        it "returns true" do
          expect(subject.CheckPath("/#{path}")).to eq(true)
        end
      end
      context "and does not begin with a slash" do
        it "returns false" do
          expect(subject.CheckPath(path.to_s)).to eq(false)
        end

        it "reports and error" do
          expect(Yast::Report).to receive(:Error).with(/The path entered is invalid/)
          subject.CheckPath(path.to_s)
        end
      end
    end
    context "when the given path size is out of the 1..69 range" do
      it "reports and error" do
        expect(Yast::Report).to receive(:Error).with(/The path entered is invalid/)
        subject.CheckPath("/#{path}/verylong")
      end
      it "returns false" do
        expect(subject.CheckPath("/#{path}/verylong")).to eq(false)
      end
    end
  end

  describe "#CheckHostname" do
    context "when the given name is between 1 and 49 characteres" do
      it "returns true if it is a valid IPv4" do
      end

      it "returns true if its a valid IPv6" do
      end

      it "returns true if it is a valid domain" do
      end
    end

    context "when the given name is out of 1..49 range" do
    end
  end
end
