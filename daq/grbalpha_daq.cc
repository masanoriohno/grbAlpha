#include<iostream>
#include<boost/asio.hpp>
#include<boost/bind.hpp>
#include <boost/thread.hpp>
#include<boost/array.hpp>


#include<TH1D.h>
#include<TCanvas.h>
#include<TFile.h>
#include<TTree.h>
#include<TSystem.h>
#include<TGraph.h>
#include<TApplication.h>

#include<vector>
#include<time.h>


#include<fstream>
using namespace boost::asio;
//global array variables for read out
boost::array<int, 32> rbuf;
boost::array<int, 32> rbuf_msb;
boost::array<int, 32> rbuf_lsb;
boost::array<int, 32> rbuf_mmsb;
boost::array<int, 32> rbuf_llsb;
boost::array<int, 32> pre_rbuf;
io_service io;
serial_port serial(io,"/dev/tty.usbserial-14201");

// callback function for asynchronous readout
void handler(
  const boost::system::error_code& error, // Result of operation.
  std::size_t bytes_transferred           // Number of bytes read.
)
{
std::cout <<"test"<<" "<<bytes_transferred<<" "<<error<<" "<< rbuf[0] << std::endl;
serial.async_read_some(
  buffer(rbuf,1),
  handler
  );
}

void read_grbalpha_packet(int datatype);
TH1D* DecompressHistogram(TH1D* binned_hist, TH1D* unbinned_hist);
TCanvas *canvas1,*canvas2;
TH1D *EventHistogram,*BinnedHistogram,*UnbinnedHistogram;
TGraph *WaveformGraph;
TFile *SaveROOTFile;
TTree *EventTree,*HistogramTree,*SCLTree;


std::vector<int> vec_vdata,vec_pre;
UInt_t ti,trigtime;
int datasize,data1,data2,data3;
int vdata;
int first_data = 1;



int main(int argc, char* argv[]){

if ( argc != 3 ) {
  std::cout << "Usage: grbalpha_daq [configfile] [exposure(sec)]" << std::endl;
  return 0;
}
char* filename = argv[1];
int exposure = atoi(argv[2]);
time_t starttime = time(NULL);

struct tm *pnow = localtime(&starttime);
char buff[128];
sprintf(buff,"%2d%02d%02d%02d%02d%02d",pnow->tm_year+1900,pnow->tm_mon+1,pnow->tm_mday,pnow->tm_hour,pnow->tm_min,pnow->tm_sec);
std::cout << buff << std::endl;

// definition of ROOT variables
TApplication *theApp;
theApp = new TApplication("app",&argc,argv);

canvas1 = new TCanvas("EventCanvas","EventCanvas",800,600);
canvas2 = new TCanvas("HistgramCanvas","HistogramCanvas",800,0,800,600);
canvas1->Divide(1,2);
canvas2->Divide(1,2);

EventHistogram = new TH1D("EventHist","EventHist",4096,0,4096);
BinnedHistogram = new TH1D("binned_hist","binned_hist",512,0,512);
UnbinnedHistogram = new TH1D("unbinned_hist","unbinned_hist",4096,0,4096);
WaveformGraph = new TGraph();
SaveROOTFile = new TFile(Form("out_%s.root",buff),"recreate");
EventTree = new TTree("eventtree","Event Telemetry");
HistogramTree = new TTree("histtree","Histogram Telemetry");
SCLTree = new TTree("scltree","SCL Telemetry");
EventTree->Branch("ti",&ti);
EventTree->Branch("trigtime",&trigtime);
EventTree->Branch("datasize",&datasize);
EventTree->Branch("PHAmax",&data1);
EventTree->Branch("data2",&data2);
EventTree->Branch("data3",&data3);
EventTree->Branch("waveform_vec",&vec_vdata);


HistogramTree->Branch("ti",&ti);
//HistogramTree->Branch("trigtime",&trigtime);
HistogramTree->Branch("datasize",&datasize);
//HistogramTree->Branch("data1",&data1);
//HistogramTree->Branch("data2",&data2);
//HistogramTree->Branch("data3",&data3);
HistogramTree->Branch("histogram_vec",&vec_vdata);

SCLTree->Branch("ti",&ti);
//HistogramTree->Branch("trigtime",&trigtime);
//scltree->Branch("datasize",&datasize);
SCLTree->Branch("LDcounter",&data1);
SCLTree->Branch("UDcounter",&data2);
SCLTree->Branch("SUDcounter",&data3);


// serial port initialization
//serial.set_option(serial_port_base::baud_rate(9600));
//serial.set_option(serial_port_base::baud_rate(19200));
serial.set_option(serial_port_base::baud_rate(38400));
serial.set_option(serial_port_base::character_size(8));
serial.set_option(serial_port_base::flow_control(serial_port_base::flow_control::none));
serial.set_option(serial_port_base::parity(serial_port_base::parity::none));
serial.set_option(serial_port_base::stop_bits(serial_port_base::stop_bits::one));



//parameter initialization
size_t length;
boost::array<unsigned char, 1> send_header_frame,send_command1_frame,send_command2_frame;
int head,com1,com2;
std::ifstream comfile(filename);
std::string parameter_name,parameter_value;
while ( comfile >> parameter_name >> parameter_value ){
  std::cout << parameter_name <<" "<<parameter_value<<std::endl;
  com1 = (atoi(parameter_value.c_str())>>0&0xff);
  com2 = (atoi(parameter_value.c_str())>>8&0xff);

if (parameter_name == "waveform_transfer_num" ){
  head = 0xff;
}
else if ( parameter_name == "pretrigger_sample"){
  head = 0xfd;
}
else if ( parameter_name == "trigger_threshold"){
  head = 0xfe;
}
else if ( parameter_name == "trigger_delay_num"){
    head = 0xfc;
}
else if ( parameter_name == "histogram_output_freq"){
    head = 0xfb;
}
else if ( parameter_name == "scl_output_freq"){
    head = 0xfa;
}
else if ( parameter_name == "debug_mode"){
    head = 0xf9;
}
if (parameter_name != "//"){
  std::cout <<std::hex<<" "<<head<<" "<<com1<<" "<<com2<<std::endl;
send_header_frame[0]=(unsigned char)head;
send_command1_frame[0]=(unsigned char)com1;
send_command2_frame[0]=(unsigned char)com2;
length = serial.write_some(buffer(send_header_frame));
length = serial.write_some(buffer(send_command1_frame));
length = serial.write_some(buffer(send_command2_frame));
}
}
comfile.close();

//boost::thread thr_io(boost::bind(&io_service::run,&io));
//serial.async_read_some(
//  buffer(rbuf,1),
//  handler
//  );
//io.run();
//}

int cnt = 0;
int peak = 0;

int val1,val2, preval;
int wfnum;
int datatype;
// first, find event data packet
while ( 1 ){
preval = val1;
length = serial.read_some(buffer(rbuf,1));
val1 = rbuf[0];
//std::cout << preval << " "<< val1 << std::endl;
//std::cout << val1 << std::endl;
if ( val1 == 0xff && preval == 0xff ) {// event data processing
  break;
}
}
// next read the first event data
read_grbalpha_packet(0xffff);

// loop for all data
while ( difftime(time(NULL),starttime) < exposure ) {
  length = serial.read_some(buffer(rbuf_lsb,1));
  length = serial.read_some(buffer(rbuf_msb,1));
  datatype = rbuf_lsb[0]+(rbuf_msb[0]<<8);
    read_grbalpha_packet(datatype);



if (datatype == 0xfffe){
  canvas2->cd(1);
  BinnedHistogram->Draw("h");
    canvas2->cd(2);
    UnbinnedHistogram = DecompressHistogram(BinnedHistogram,UnbinnedHistogram);
  UnbinnedHistogram->Draw("h");
  canvas2->Update();
  HistogramTree->Fill();

}
else if ( datatype == 0xfffd ) {
  SCLTree->Fill();
}

else if ( datatype == 0xffff ) {

  canvas1->cd(1);
  EventHistogram->Draw();
  canvas1->cd(2);
  WaveformGraph->SetMarkerStyle(2);
  WaveformGraph->SetLineColor(2);
  WaveformGraph->GetYaxis()->SetRangeUser(0,4100);
  if ( data1 < 4096 )  WaveformGraph->Draw("APL");
  canvas1->Update();
  EventTree->Fill();
  cnt ++;
}
  gSystem->ProcessEvents();
}
BinnedHistogram->Write();
UnbinnedHistogram->Write();
SaveROOTFile->Write();
SaveROOTFile->Close();

}
// basic fucntion to read out grbAlpha data packet
void read_grbalpha_packet(int datatype){
  size_t length;
  int wfnum;

  wfnum = 0;
  vec_vdata.clear();
// 1. 4byte TI
length = serial.read_some(buffer(rbuf_lsb,1));
length = serial.read_some(buffer(rbuf_msb,1));
length = serial.read_some(buffer(rbuf_llsb,1));
length = serial.read_some(buffer(rbuf_mmsb,1));
ti = rbuf_lsb[0]+(rbuf_msb[0]<<8)+(rbuf_llsb[0]<<16)+(rbuf_mmsb[0]<<24);
// 2. 4byte trigtime
length = serial.read_some(buffer(rbuf_lsb,1));
length = serial.read_some(buffer(rbuf_msb,1));
length = serial.read_some(buffer(rbuf_llsb,1));
length = serial.read_some(buffer(rbuf_mmsb,1));
trigtime =rbuf_lsb[0]+(rbuf_msb[0]<<8)+(rbuf_llsb[0]<<16)+(rbuf_mmsb[0]<<24);
// 3. 2 byte datasize
length = serial.read_some(buffer(rbuf_lsb,1));
length = serial.read_some(buffer(rbuf_msb,1));
datasize = rbuf_lsb[0]+(rbuf_msb[0]<<8);
// 3. 2byte data1
length = serial.read_some(buffer(rbuf_lsb,1));
length = serial.read_some(buffer(rbuf_msb,1));
data1 = rbuf_lsb[0]+(rbuf_msb[0]<<8);
if (datatype == 0xffff ) EventHistogram->Fill(data1);
// 4. 2byte data2 (data size)
length = serial.read_some(buffer(rbuf_lsb,1));
length = serial.read_some(buffer(rbuf_msb,1));
data2 = rbuf_lsb[0]+(rbuf_msb[0]<<8);
// 5. 2byte data3
length = serial.read_some(buffer(rbuf_lsb,1));
length = serial.read_some(buffer(rbuf_msb,1));
data3 = rbuf_lsb[0]+(rbuf_msb[0]<<8);
//if (datatype == 0xfffe) std::cout << datatype <<" "<< ti <<" "<<trigtime<<" "<<datasize<<" "<<data1<<" "<<data2<<" "<<data3<<std::endl;

// 6. Nbyte vdata (0xffff:waveform, 0xfffe:histogram (non-reset counter))
int num_of_data = 0;
int diff_vec;
int unbinned_channel = 0;
while ( num_of_data < datasize ){
length = serial.read_some(buffer(rbuf_lsb,1));
length = serial.read_some(buffer(rbuf_msb,1));
vdata = rbuf_lsb[0]+(rbuf_msb[0]<<8);
//if (datatype == 0xfffe) std::cout << std::dec << vdata << std::endl;
  vec_vdata.push_back(vdata);
if (datatype == 0xffff )  {
  WaveformGraph->SetPoint(num_of_data,num_of_data,vdata);
  WaveformGraph->GetXaxis()->SetRangeUser(0,datasize);
}
if (datatype == 0xfffe )  {
  if ( first_data )   {
    vec_pre.push_back(vdata);
  }
  else if ( ! first_data ) {
    diff_vec = vdata - vec_pre[num_of_data];
    if ( diff_vec < 0 ) diff_vec = vdata+pow(2,16) - vec_pre[num_of_data];
//    hist->SetBinContent(num_of_data,diff_vec);
    BinnedHistogram->AddBinContent(num_of_data,diff_vec);

      vec_pre[num_of_data] = vdata;
}
}
num_of_data ++;
}
if ( datatype == 0xfffe ) first_data = 0;

}

TH1D* DecompressHistogram(TH1D* binned_hist, TH1D* UnbinnedHistogram){
  // unbin histogram
  // binning table
  // 0-255 : 2
  // 256-767 : 4
  // 768-1279 : 8
  // 1280-2304 : 16
  // 2304-4096 : 32
int unbinned_channel = 0;
for (int num_of_data=0; num_of_data<binned_hist->GetXaxis()->GetNbins(); ++num_of_data){
 int diff_vec = binned_hist->GetBinContent(num_of_data);
  int binning_factor = 2;
  if ( num_of_data < 128 ) {
    binning_factor = 2;
    for (int bin=0; bin<binning_factor; ++bin ) {
    UnbinnedHistogram->SetBinContent(unbinned_channel,diff_vec/binning_factor);
    unbinned_channel++;
  }
}
else if ( num_of_data < 256 ) {
    binning_factor = 4;
    for (int bin=0; bin<binning_factor; ++bin ) {
    UnbinnedHistogram->SetBinContent(unbinned_channel,diff_vec/binning_factor);
    unbinned_channel++;
  }
}
else    if ( num_of_data < 256+64) {
    binning_factor = 8;
    for (int bin=0; bin<binning_factor; ++bin ) {
    UnbinnedHistogram->SetBinContent(unbinned_channel,diff_vec/binning_factor);
    unbinned_channel++;
  }
}
else      if ( num_of_data < 256+64+64 ) {
    binning_factor = 16;
    for (int bin=0; bin<binning_factor; ++bin ) {
    UnbinnedHistogram->SetBinContent(unbinned_channel,diff_vec/binning_factor);
    unbinned_channel++;
  }
}
else  if ( num_of_data < 256+64+64+64 ) {
binning_factor = 32;
for (int bin=0; bin<binning_factor; ++bin ) {
UnbinnedHistogram->SetBinContent(unbinned_channel,diff_vec/binning_factor);
unbinned_channel++;
}
}
}
return UnbinnedHistogram;
}
