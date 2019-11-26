`include "ram_256_16bit.v"
`include "osdvu/uart.v"
`include "pll.v"
`include "dout_eventdata.v"
`include "dpram.v"
`include "dummyADC.v"

module readgrbalpha_top(
    input CLK_i,
    input RSTn_i,
    input RS232_RX_i,
    output RS232_TX_o,
    output [7:0] LED_o,
// ADC module
		output CS,
		output SCLK,
		input SDO
);


parameter mem_wait = 5;
reg debug_flag = 1;
wire CLK;
assign CLK = sysclock;
//assign CLK = CLK_i;
reg transmit2;
// reg [7:0] tx_byte;
wire [7:0] rx_byte;
wire [7:0] tx_byte;
wire received;
wire test;
wire is_tansmitting;
reg [31:0] tx_cnt;
reg [7:0] tx_data;


// control module for data output timing
reg transmit_trig_event,transmit_trig2_event;
reg transmit_trig_hist,transmit_trig2_hist;
reg transmit_trig_scl,transmit_trig2_scl;
reg transmit_timing_event,transmit_timing_hist,transmit_timing_scl;
reg [31:0]ti;
reg [15:0]event_send_count = 0;
reg [15:0]event_send_count_scl = 0;
// parameters
reg [15:0] histogram_output_freq = 100;
reg [15:0] scl_output_freq = 20;
//
// for histogram data
always @(negedge event_sending ) begin
if ( !RSTn_i ) event_send_count <= 0;
else begin
event_send_count <= event_send_count + 1;
if (event_send_count == histogram_output_freq ) begin  // histogram data is sent after 100 event data sending
if ( histogram_output_freq > 0 ) transmit_trig_hist <= 1;
event_send_count <= 0;
end
else transmit_trig_hist <= 0;
end
end
// for scaler data
always @(negedge event_sending ) begin
if ( !RSTn_i ) event_send_count_scl <= 0;
else begin
event_send_count_scl <= event_send_count_scl + 1;
if (event_send_count_scl == scl_output_freq ) begin  // histogram data is sent after 100 event data sending
if ( scl_output_freq > 0 ) transmit_trig_scl <= 1;
event_send_count_scl <= 0;
end
else transmit_trig_scl <= 0;
end
end
// for event data
always @(posedge CLK) begin
if ( !RSTn_i ) begin
tx_cnt <= 0;
end
else begin
tx_cnt <= tx_cnt + 1;
if ( tx_cnt[1] ) begin  //event data is sent almost always
transmit_trig_event <= 1;
end
else begin
transmit_trig_event <= 0;
end
transmit_trig2_event <= transmit_trig_event;
transmit_trig2_hist <= transmit_trig_hist;
transmit_trig2_scl <= transmit_trig_scl;
transmit_timing_event <= transmit_trig_event && !transmit_trig2_event;
transmit_timing_hist <= transmit_trig_hist && !transmit_trig2_hist;
transmit_timing_scl <= transmit_trig_scl && !transmit_trig2_scl;
end
end


// signals for histgraming Process
reg [15:0]peak_hist = 0;
reg [7:0]sampling_counter;
reg [3:0] hist_state;
reg [15:0] count;
wire [15:0] hist_count;
reg [15:0] hist_count_addone;
reg [15:0] hist_address;
reg write_hist= 0;
wire hist_sending;
reg write_done;
wire [15:0] hist_readout_data;
parameter HIST_FINDPEAK = 0;
parameter HIST_BINNING = 1;
parameter HIST_READOUT = 2;
parameter HIST_ADDONE = 3;
parameter HIST_WRITE = 4;


// signals for data storing state machine
reg [3:0] bram_state;
parameter BRAM_WRITE_IDLE = 0;
parameter BRAM_WRITE_WRITE = 1;
parameter BRAM_WRITE_FREEZE = 2;
reg bram_freeze_flg;
reg [7:0] bram_freeze_countdown = 255;
wire [7:0] bram_send_countdown;
reg [7:0] clkcnt;
reg [15:0] din;
wire [15:0] dout;
wire [15:0] ADCdelayN;
wire [7:0]  raddr;
reg [7:0]  delayaddr;
reg       wclk;
reg write_en = 1;
reg [7:0] waddr;
reg [15:0] datacnt;
wire [15:0] dummyADC;
wire [15:0] dummyADC_template;
reg [7:0] addcnt;
reg [31:0] trigtime;
reg bram_ready;
reg [7:0]raddr_start;
reg [15:0]peak;
wire transmit_event;
wire event_sending;
wire scl_sending;
wire [7:0]tx_byte_event;
wire [15:0]testreg;


// data output control modules
// parameters
reg [7:0] waveform_transfer_num = 32;
//
dout_eventdata inst_dout_eventdata(
  .CLK(CLK),
  .RSTn_i(RSTn_i),
  .mem_wait(mem_wait),
  .transmit_timing(transmit_timing_event),
  .header(16'hffff),
  .ti(tx_cnt),
  .trigtime(trigtime),
  .datasize(waveform_transfer_num),
  .data1(peak),
  .data2(peak_hist),
  .data3(hist_address),
  .vdata(dout),
  .raddr_start(raddr_start),
  .is_transmitting(is_transmitting),
  .tx_busy(hist_sending|scl_sending),
//  .tx_busy(0),
  .data_length(waveform_transfer_num),
  .running_o(event_sending),
  .transmit_start(bram_ready),
  .raddr_o(raddr),
  .transmit_o(transmit_event),
  .test_o(testreg),
  .bram_send_countdown_o(bram_send_countdown),
  .tx_byte_o(tx_byte_event)
  );

wire transmit_hist;
wire bram_send_countdown_hist;
wire [7:0]tx_byte_hist;
wire [8:0]hist_readaddr;

  dout_eventdata inst_dout_histdata(
    .CLK(CLK),
    .RSTn_i(RSTn_i),
    .mem_wait(mem_wait),
    .transmit_timing(transmit_timing_event),
    .header(16'hfffe),
    .ti(tx_cnt),
    .trigtime(trigtime),
    .datasize(512),
    .data1(2),
    .data2(3),
    .data3(4),
    .vdata(hist_readout_data),
    .raddr_start(0),
    .is_transmitting(is_transmitting),
    .tx_busy(event_sending|scl_sending),
    .data_length(512),
    .running_o(hist_sending),
    .transmit_start(transmit_timing_hist),
    .raddr_o(hist_readaddr),
    .transmit_o(transmit_hist),
    .bram_send_countdown_o(bram_send_countdown_hist),
    .tx_byte_o(tx_byte_hist)
    );
wire transmit_scl;
wire [7:0]tx_byte_scl;
reg [15:0] ld_counter,ud_counter,sud_counter;
wire bram_send_countdown_scl;
wire [15:0] scl_readaddr;

    dout_eventdata inst_dout_scldata(
      .CLK(CLK),
      .RSTn_i(RSTn_i),
      .mem_wait(mem_wait),
      .transmit_timing(transmit_timing_event),
      .header(16'hfffd),
      .ti(tx_cnt),
      .trigtime(trigtime),
      .datasize(0),
      .data1(ld_counter),
      .data2(ud_counter),
      .data3(sud_counter),
      .vdata(0),
      .raddr_start(0),
      .is_transmitting(is_transmitting),
      .tx_busy(event_sending|hist_sending),
      .data_length(0),
      .running_o(scl_sending),
      .transmit_start(transmit_timing_scl),
      .raddr_o(scl_readaddr),
      .transmit_o(transmit_scl),
      .bram_send_countdown_o(bram_send_countdown_scl),
      .tx_byte_o(tx_byte_scl)
      );

wire transmit;
assign transmit = transmit_event | transmit_hist | transmit_scl;
assign tx_byte = tx_byte_event | tx_byte_hist | tx_byte_scl;


// uart module
//uart #(.CLOCK_DIVIDE( 313 )) my_uart ( // for 12 MHz clock case baud_rate 9600
   //uart #(.CLOCK_DIVIDE( 156 )) my_uart ( // for 12 MHz clock case baud_rate 19200
//   uart #(.CLOCK_DIVIDE( 78 )) my_uart ( // for 12 MHz clock case baud_rate 38400
   uart #(.CLOCK_DIVIDE( 195 )) my_uart ( // for 30 MHz clock case baud_rate 38400
//        uart #(.CLOCK_DIVIDE( 228 )) my_uart ( // for 35 MHz clock case baud_rate 38400
//   uart #(.CLOCK_DIVIDE( 261 )) my_uart ( // for 40 MHz clock case baud_rate 38400
//   uart #(.CLOCK_DIVIDE( 1041 )) my_uart ( // for 30 MHz clock case baud_rate 38400
//   uart #(.CLOCK_DIVIDE( 390 )) my_uart ( // for 60 MHz clock case baud_rate 38400
    CLK,          //  master clock for this component
    ,               // synchronous reset line (resets if high)
    RS232_RX_i,     // receive data on this line
    RS232_TX_o,     // transmit data on this line
    transmit,       // signal o indicate that the UART should start a transmission
   tx_byte,        // 8-bit bus with byte to be transmitted when transmit is raised high
    received,       // output flag raised high for one cycle of clk when a byte is received
    rx_byte,        // byte which has just been received when received is raise
    ,               // indicates that we are currently receiving data on the rx lin
   is_transmitting, 		// indicates that we are currently sending data on the tx line
    );


// adc management process
   assign SCLK = CLK;
   reg      iCS = 1;
   assign CS = iCS;
   reg [11:0] ADC;
   reg [7:0] SCLK_counter;
   always @(posedge CLK) begin
      if ( !RSTn_i ) SCLK_counter <= 0;
      else  SCLK_counter <= SCLK_counter + 1;
      if ( SCLK_counter == 18 ) SCLK_counter <= 0;
   end

   always @(posedge CLK) begin
            if ( SCLK_counter == 0 ) iCS <= 0;
      else if ( SCLK_counter == 14 ) iCS <= 1;
   end

   always @(posedge SCLK) begin
      if ( !RSTn_i ) ADC <= 0;
      else if ( !debug_flag && iCS == 0 && SCLK_counter > 1 && SCLK_counter < 14) ADC[11-SCLK_counter+2] <= SDO;
      else if ( debug_flag ) ADC <= dummyADC;
   end
   // one-shot pulse of rising edge of CS
reg 	      iCS2,cs;
always @(posedge CLK) begin
   if ( !RSTn_i ) begin
iCS2 <= 0;
cs <= 0;
   end
   iCS2 <= iCS;
   cs <= iCS && !iCS2;
end

   // dummy waveform data for debug
   dummyADC dummyADC_inst(
  .CLK_i(CLK),
  .RSTn_i(RSTn_i),
  .cs(cs),
  .dummyADC_o(dummyADC)
     );

     // simple trigger module
      //parameterss
      reg [15:0] trigger_threshold = 100;
//      reg [15:0] trigger_threshold = 2000;




reg trig = 0;
reg trig_hist = 0;
reg trig2 = 0;
reg trig_hist2 =0;
reg trig_pulse = 0;
reg trig_hist_pulse = 0;
reg [15:0]ADCbaseline;

always @(posedge CLK) begin
if (!RSTn_i) begin
trig <= 0;
trig_hist <= 0;
end
else if ( ADC> ADCdelayN && ADC-ADCdelayN > trigger_threshold ) begin
trig <= 1;
trig_hist <= 1;
ADCbaseline <= 550;
if ( trig_pulse == 1 ) trigtime <= tx_cnt;
end
else if ( bram_send_countdown == 0 ) begin
trig <= 0;
end
else if ( write_done ) begin
trig_hist <= 0;
end
trig2 <= trig;
trig_hist2 <= trig_hist;
trig_pulse <= trig && !trig2;
trig_hist_pulse <= trig_hist && !trig_hist2;
end

// scaler process
always @(posedge CLK) begin
if ( !RSTn_i ) begin
ld_counter <= 0;
ud_counter <= 0;
sud_counter <= 0;
end
else if ( trig_hist_pulse ) ld_counter <= ld_counter + 1;
else if ( write_done && peak_hist > 4000 ) ud_counter <= ud_counter + 1;
else if ( write_done && peak_hist > 4090 ) sud_counter <= sud_counter + 1;
end


// histgraming Process
reg [3:0]hist_write_wait=mem_wait;
reg [3:0]hist_read_wait=mem_wait;
reg [15:0]raw_hist_address;
always @(posedge CLK) begin
if ( !RSTn_i ) begin
sampling_counter <= 0;
hist_state <= 0;
end
else begin
//if ( 1 ) peak_hist <= ADC;
case (hist_state)
HIST_FINDPEAK: begin
write_done <= 0;
hist_write_wait <= mem_wait;
hist_read_wait <= mem_wait;
if ( trig_hist && cs && sampling_counter < 10 ) begin
if (ADC > peak_hist ) peak_hist <= ADC;
sampling_counter <= sampling_counter + 1;
end
if ( sampling_counter == 10 && !hist_sending) begin // histogram peak is ready
//hist_address <= peak_hist[11:3];
//hist_address <= peak_hist[11:3];
raw_hist_address <= peak_hist - ADCbaseline;
//raw_hist_address <= peak_hist[11:3];
hist_state <= HIST_BINNING;
end
end

HIST_BINNING: begin

if ( raw_hist_address < 256 ) hist_address <= (raw_hist_address>>1);
else if ( raw_hist_address >= 256 && raw_hist_address < 768 ) hist_address <= (raw_hist_address>>2)+64;
else if ( raw_hist_address >= 768 && raw_hist_address < 1280 ) hist_address <= (raw_hist_address>>3)+160;
else if ( raw_hist_address >= 1280 && raw_hist_address < 2304 ) hist_address <= (raw_hist_address>>4)+224;
else if ( raw_hist_address >= 2304 &&  raw_hist_address < 4096 ) hist_address <= (raw_hist_address>>5)+288;

//hist_address <= raw_hist_address;
hist_state <= HIST_READOUT;
end


HIST_READOUT: begin
count <= hist_count;
hist_read_wait <= hist_read_wait - 1;
if ( hist_read_wait == 0 ) begin
hist_read_wait <= mem_wait;
hist_state <= HIST_ADDONE;
end
end
HIST_ADDONE: begin
 count <= count + 1;
write_hist <= 1;
hist_state <= HIST_WRITE;
peak_hist <= 0;
end
HIST_WRITE: begin
hist_write_wait <= hist_write_wait - 1;
hist_count_addone <= count;
if ( hist_write_wait == 0 ) begin
hist_state <= HIST_FINDPEAK;
write_hist <= 0;
sampling_counter <= 0;
peak_hist <= 0;
write_done <= 1;
hist_write_wait <= mem_wait;
end
end
endcase
end
end

// save waveform process
// parameters
reg [15:0] pretrigger_sample = 10;
reg [15:0] trigger_delay_num = 5;
//
reg [3:0] ram_write_wait = mem_wait;
always @(posedge CLK) begin
if ( !RSTn_i ) begin
write_en <= 1;
waddr <= 0;
delayaddr <= 0;
din <= 0;
bram_freeze_flg <= 0;
bram_ready <= 0;
peak <= 0;
//bram_freeze_countdown <= 245;
bram_freeze_countdown <= 255 - pretrigger_sample;
bram_state <= BRAM_WRITE_IDLE;
end
else begin
din <= ADC;

case (bram_state)

  BRAM_WRITE_IDLE: begin
  if ( bram_send_countdown == 0 ) begin
  bram_freeze_flg <= 0;
  write_en <= 1;
  bram_ready <= 0;
  peak <= 0;
//  bram_freeze_countdown <= 245;
  bram_freeze_countdown <= 255 - pretrigger_sample;
  end
  if (cs && !bram_freeze_flg ) begin
  bram_state <= BRAM_WRITE_WRITE;
  end
  end

  BRAM_WRITE_WRITE: begin
//  din <= ADC;
  if ( ADC > peak ) peak <= ADC;
  ram_write_wait <= ram_write_wait - 1;
  if ( ram_write_wait == 0 ) begin
  waddr <= waddr + 1;
  delayaddr <= waddr - trigger_delay_num;
  ram_write_wait <= mem_wait;
  if ( trig ) begin
//  if ( bram_freeze_countdown == 245 ) raddr_start <= waddr-10;
  if ( bram_freeze_countdown == 255 - pretrigger_sample ) raddr_start <= waddr-pretrigger_sample;
  bram_state <= BRAM_WRITE_FREEZE;
  end
  else bram_state <= BRAM_WRITE_IDLE;
  end
  end

  BRAM_WRITE_FREEZE: begin
  if ( cs ) begin
  bram_freeze_countdown <= bram_freeze_countdown - 1;
  bram_state <= BRAM_WRITE_WRITE;
  end
  if (bram_freeze_countdown == 0 ) begin
  bram_freeze_flg <= 1;
  bram_ready <= 1;
  write_en <= 0;
  bram_state <= BRAM_WRITE_IDLE;
  end
  end


endcase
end
end



//primitive ram for waveform saving

ram_256_16bit ram_inst(
    .din(din),
    .write_en(write_en),
    .waddr(waddr),
    .wclk(CLK),
    .raddr(raddr),
    .rclk(CLK),
    .dout(dout)
);
/*
wire [15:0]out_test;
dpram2 ram_inst(
  .clk(CLK),
  .load1(write_en),
  .load2(0),
  .addr1(waddr),
  .addr2(raddr),
  .d1(din),
  .d2(0),
  .q1(out_test),
  .q2(dout)
  );
  */
// primitive ram for delayed ADC data
ram_256_16bit ram_adcdelay(
    .din(din),
    .write_en(write_en),
    .waddr(waddr),
    .wclk(CLK),
    .raddr(delayaddr),
    .rclk(CLK),
    .dout(ADCdelayN)
  );

  // dual port ram for histogram data

dpram dram_histogram(
  .clk(CLK),
  .load1(write_hist),
  .load2(0),
  .addr1(hist_address),
  .addr2(hist_readaddr),
  .d1(hist_count_addone),
  .d2(0),
  .q1(hist_count),
  .q2(hist_readout_data)
  );



//PLL
wire sysclock;
wire locked;
pll myPLL(
  .clock_in(CLK_i),
  .clock_out(sysclock),
  .locked(locked)
  );

//assign LED_o = hist_count_lsb;
//command handler
reg [7:0] command_head;
reg [7:0] command_body_lsb;
reg [7:0] command_body_msb;
wire [15:0] command_body;
reg [7:0] command_timeout;
assign command_body = {command_body_msb,command_body_lsb};

parameter CMD_RCV_WAIT_HEAD = 0;
parameter CMD_RCV_WAIT_BODY_LSB = 1;
parameter CMD_RCV_WAIT_BODY_MSB = 2;
parameter CMD_RCV_DECODE = 3;
reg [3:0] cmd_state;
always @(posedge CLK) begin
if ( !RSTn_i) begin
cmd_state <= 0;
command_head <= 0;
command_timeout <= 0;
end
else begin
command_timeout <= command_timeout + 1;
case (cmd_state)
CMD_RCV_WAIT_HEAD: begin
command_timeout <= 0;
if ( received ) begin
command_head <= rx_byte;
cmd_state <= CMD_RCV_WAIT_BODY_LSB;
end
end
CMD_RCV_WAIT_BODY_LSB: begin
if ( received ) begin
command_body_lsb <= rx_byte;
cmd_state <= CMD_RCV_WAIT_BODY_MSB;
end
end
CMD_RCV_WAIT_BODY_MSB: begin
if ( received ) begin
command_body_msb <= rx_byte;
cmd_state <= CMD_RCV_DECODE;
end
end
CMD_RCV_DECODE: begin
// command decoding..
if ( command_head == 8'hff )  waveform_transfer_num <= command_body;
else if ( command_head == 8'hfe ) trigger_threshold <= command_body;
else if ( command_head == 8'hfd ) pretrigger_sample <= command_body;
else if ( command_head == 8'hfc ) trigger_delay_num <= command_body;
else if ( command_head == 8'hfb ) histogram_output_freq <= command_body;
else if ( command_head == 8'hfa ) scl_output_freq <= command_body;
else if ( command_head == 8'hf9 ) debug_flag <= command_body;
cmd_state <= CMD_RCV_WAIT_HEAD;
end
endcase
end
end

assign LED_o[7:1] = event_send_count[7:1]; //to see event data output process is running
//assign LED_o[7:1] = hist_address; //to see event data output process is running
assign LED_o[0] = debug_flag; //to see event data output process is running
//assign LED_o = command_head;
//assign LED_o = command_body[15:8]; //to see event data output process is running
//assign LED_o[7:4] = command_head;
//assign LED_o[3:0] = command_body;


endmodule // readgrbalpha_top
