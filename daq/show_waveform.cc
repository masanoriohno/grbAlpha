void show_waveform(int wfnum=1, string rootfilename="out.root"){
TFile *f = new TFile(rootfilename.c_str());
TTree *tree = (TTree*)f->Get("eventtree");
std::vector<int> *vec=0;
tree->SetBranchAddress("waveform_vec",&vec);

tree->GetEntry(wfnum);
TGraph *graph = new TGraph();
for (int i=0; i<vec->size(); ++i){
cout << vec->at(i) << endl;
graph->SetPoint(i,i,vec->at(i));
}
graph->SetMarkerStyle(3);
graph->Draw("APL");
}
