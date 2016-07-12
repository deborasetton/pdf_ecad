describe "Ecad PDF Import" do
  before(:each) do
    @importer = Importers::PdfEcad.new(File.expand_path('../careqa.pdf', __FILE__))
  end

  it "should list all works" do
    @importer.works.count.should == 130
    @importer.works[0][:iswc].should == "T-039.782.970-7"
    @importer.works.last[:external_ids][0][:source_id].should == "126227"
    @importer.works[9][:right_holders].size.should == 4
    @importer.works[9][:right_holders][2][:share].should == 25.00
  end

  it "should recognize a right holder for 100% line" do
    line = "4882         CARLOS DE SOUZA                        CARLOS CAREQA            582.66.28.18 ABRAMUS          CA   100,                        1"
    rh = @importer.right_holder(line)
    rh[:name].should == "CARLOS DE SOUZA"
    rh[:pseudos][0][:name].should == "CARLOS CAREQA"
    rh[:pseudos][0][:main].should == true
    rh[:role].should == "Author"
    rh[:society_name].should == "ABRAMUS"
    rh[:ipi].should == "582662818"
    rh[:external_ids][0][:source_name].should == "Ecad"
    rh[:external_ids][0][:source_id].should == "4882"
    rh[:share].should == 100
  end

  it "should recognize share for broken percent" do
    line = "16863        EDILSON DEL GROSSI FONSECA             EDILSON DEL GROSSI                     SICAM           CA 33,33                         2"
    rh = @importer.right_holder(line)
    rh[:name].should == "EDILSON DEL GROSSI FONSECA"
    rh[:share].should == 33.33
    rh[:ipi].should be_nil
  end

  it "should recognize share in right holder line" do
    line = "741          VELAS PROD. ARTISTICAS MUSICAIS E      VELAS                    247.22.09.80 ABRAMUS           E   8,33 20/09/95               2"
    rh = @importer.right_holder(line)
    rh[:name].should == "VELAS PROD. ARTISTICAS MUSICAIS E"
    rh[:share].should == 8.33
  end

  it "should return nil if it is not a right_holder" do
    line = "3810796       -   .   .   -          O RESTO E PO                                                LB             18/03/2010"
    rh = @importer.right_holder(line)
    rh.should be_nil
  end

  it "should recognize work in line" do
    line = "3810796       -   .   .   -          O RESTO E PO                                                LB             18/03/2010"
    work = @importer.work(line)
    work.should_not be_nil
    work[:iswc].should == "-   .   .   -"
    work[:title].should == "O RESTO E PO"
    work[:external_ids][0][:source_name].should == "Ecad"
    work[:external_ids][0][:source_id].should == "3810796"
    work[:situation].should == "LB"
    work[:created_at].should == "18/03/2010"
  end
end
