module dpram(clk, load1, load2, addr1, addr2, d1, d2, q1, q2);

   parameter DWIDTH=16,AWIDTH=9,WORDS=512;



   input clk,load1,load2;

   input [AWIDTH-1:0] addr1,addr2;

   input [DWIDTH-1:0] d1,d2;

   output [DWIDTH-1:0] q1,q2;

   reg [DWIDTH-1:0]    q1,q2;

   reg [DWIDTH-1:0]    mem [WORDS-1:0];


    always @(posedge clk)
      begin
	 if(load1) mem[addr1] <= d1;

	 q1 <= mem[addr1];

      end

    always @(posedge clk)
      begin
	 if(load2) mem[addr2] <= d2;

	 q2 <= mem[addr2];

      end

   integer i;

    initial begin
       for(i=0;i<WORDS;i=i+1)
	 mem[i]=0;
         // ここにメモリの初期化（mem[12'h001]=16'h1234;など）を書く．
    end

endmodule // dpram
