module dummyADC (
  input CLK_i,
  input RSTn_i,
  input cs,
    output [15:0]dummyADC_o );


   reg [7:0]datacnt;
   reg [15:0]dummyADC;
   assign dummyADC_o = dummyADC;

   // dummy waveform data for debug
   always @(posedge CLK_i) begin
   if ( !RSTn_i ) begin
   datacnt <= 0;
   end
   else
   if ( cs ) begin
   datacnt <= datacnt + 1;
   end
dummyADC <= 500;
  // if (  datacnt <= 20 ) dummyADC <= 500;
/*
   else if ( datacnt <= 30 ) dummyADC <= 500+(datacnt-20)*100;
//   else if ( datacnt <= 30 ) dummyADC <= 700;
   else if ( datacnt < 60 ) dummyADC <= 500;
   else if ( datacnt == 255 ) datacnt <= 0;
*/
   end



endmodule
