#include<iostream>
#include<fstream>
#include<math.h>
#include<random>

int main(){
std::ifstream templatefile("wf_template_nooffset.dat");
int template_wf[256];
int i=0;
while ( templatefile >> template_wf[i] ){
++i;
}
int src_begin = 29;
int src_end = 60;
int wfnum = 100;
std::mt19937_64 mt(3);
std::normal_distribution<> norm(600,30);
std::normal_distribution<> norm_peak(1,1);
std::uniform_int_distribution<> rand_tstart(0,src_begin);
std::uniform_int_distribution<> rand_tstop(src_end,100);
for (int i=0; i<1000; ++i){//num_of_wf
for (int j=rand_tstart(mt); j<rand_tstop(mt); ++j){
std::cout << template_wf[j]*(int)norm_peak(mt)+(int)norm(mt) << std::endl;
}
}
}
