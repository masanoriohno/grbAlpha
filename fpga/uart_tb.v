module uart_tb;

   reg CLK_i,RSTn_i,RS232_RX_i,SDO;
   
wire RS232_TX_o,CS,SCLK;
wire [7:0]LED_o;
wire test_out;

   
readgrbalpha_top readgrbalpha_top_tb(CLK_i,RSTn_i,RS232_RX_i,RS232_TX_o,LED_o,CS,SCLK,SDO);

initial begin
$dumpfile("uart_tb.vcd");
$dumpvars(0,readgrbalpha_top_tb);

CLK_i = 0;
RSTn_i = 0;
RS232_RX_i = 0;
   SDO = 2523;
#15 RSTn_i = 1;
#5000000 $finish;
end

always #5 CLK_i  = !CLK_i;


endmodule
