void makespec(){
TTree *tree = (TTree*)gROOT->FindObject("eventtree");
std::vector<int> *vec=0;
TH1D *h = new TH1D("h","h",4096,0,4096);
tree->SetBranchAddress("waveform_vec",&vec);
for (int j=0; j<tree->GetEntries(); ++j){
tree->GetEntry(j);
int peak = 0;
for (int i=0; i<vec->size(); ++i){
int pha = vec->at(i);
if ( pha > peak ) peak = pha;
}
h->Fill(peak);
}
h->Draw();
}
