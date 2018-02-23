require_relative "spec_helper"

module Yast
  # just a wrapper class for the nfs/ui.rb
  class NfsUiIncludeTesterClass < Module
    extend Yast::I18n

    def main
      Yast.include self, "nfs/ui.rb"
    end
  end
end

NfsUiIncludeTester = Yast::NfsUiIncludeTesterClass.new
NfsUiIncludeTester.main

describe "Yast::NfsUiInclude" do
  subject { NfsUiIncludeTester }
  let(:server) { "nfs.suse.cz" }
  let(:v4) { true }

  describe "#scan_exports" do
    before do
      # mocks for the feedback popup
      allow(Yast::UI).to receive(:OpenDialog).and_return(true)
      allow(Yast::UI).to receive(:CloseDialog)
      allow(Yast::UI).to receive(:WidgetExists).and_return(true)

      allow(Yast::UI).to receive(:ChangeWidget)
    end

    context "scan fails" do
      before do
        expect(Yast::Nfs).to receive(:ProbeExports)
      end

      it "reports error when scan fails" do
        expect(Yast::Report).to receive(:Error).with(/scan failed/)
        subject.scan_exports(server, v4)
      end
    end

    context "scan succeeds" do
      let(:export) { "/export" }
      before do
        expect(Yast::Nfs).to receive(:ProbeExports).and_return([export])
      end

      it "displays a dialog for selecting the export" do
        expect(subject).to receive(:ChooseExport).and_return(export)
        subject.scan_exports(server, v4)
      end

      it "sets the selected export in the add dialog" do
        allow(subject).to receive(:ChooseExport).and_return(export)
        expect(Yast::UI).to receive(:ChangeWidget).with(Id(:pathent), :Value, export)
        subject.scan_exports(server, v4)
      end
    end
  end
end
