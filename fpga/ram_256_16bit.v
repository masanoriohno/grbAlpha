
module ram_256_16bit (
input [15:0]din, 
input write_en, 
input [7:0]waddr, 
input wclk, 
input [7:0]raddr, 
input rclk, 
output [15:0]dout);

   SB_RAM40_4K #(
		   .WRITE_MODE(0),
		   .READ_MODE(0)
		 ) ram40_4k_256x16bit (
				     .RDATA(dout),
				     .RADDR(raddr),
				     .RCLK(rclk),
				     .RCLKE(1'b1),
				     .RE(1'b1),
				     .WADDR(waddr),
				     .WCLK(wclk),
				     .WCLKE(1'b1),
				     .WDATA(din),
				     .MASK(0),
				     .WE(write_en)
				   );


endmodule // ram_256_16bit



   
   
