void show_hist(string rootfilename="out.root"){
TFile *f = new TFile(rootfilename.c_str());
TTree *tree = (TTree*)f->Get("histtree");
std::vector<int> *vec=0;
tree->SetBranchAddress("histogram_vec",&vec);
TH1D *h1 = new TH1D("h","h",512,0,512);
TH1D *h2 = new TH1D("h2","h2",512,0,512);

for (int j=1; j<tree->GetEntries(); ++j){
ofstream outfile(Form("hist%d.dat",j));
tree->GetEntry(j);
for (int i=0; i<vec->size(); ++i){
outfile << i <<" "<<vec->at(i)<<endl;
}
}
}
