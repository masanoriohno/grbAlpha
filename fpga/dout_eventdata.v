
module dout_eventdata(
input CLK,      //control clock
input RSTn_i,   //power-on reset
input [3:0]mem_wait,
input transmit_timing,  //transmit timing for each data
input [15:0]header,      //header data
input [32:0]ti,         //time counter
input [32:0]trigtime,   //another time data
input [15:0]datasize,  //datasize
input [15:0]data1,    //2bytes data
input [15:0]data2,    //2bytes data
input [15:0]data3,   //support up to 3 of 2bytes data transfer
input [15:0]vdata,   //output 2bytes variable length data
input [7:0]raddr_start,  //start memory address for variable length data
input [15:0]data_length, //define output data length
input is_transmitting,  //to know the tx data output process is running or not
input transmit_start,   //data transfer start timing for this data packet
input tx_busy,         //to indicate other packet data transfer is running or not
output running_o,       // to indicate this packet data transfer is running or not
output [15:0]raddr_o,   //memory address to be read
output  [15:0]bram_send_countdown_o, //readout count for the variable length data
output transmit_o,     //1byte data transmitting timing for serial data transfer module
output [15:0]test_o,
output [7:0]tx_byte_o  //output serial data

  );


// define output lines
//reg [15:0]raddr = 0;
reg [15:0]raddr = 0;
assign raddr_o = raddr;
reg [15:0]bram_send_countdown = 10;
assign bram_send_countdown_o = bram_send_countdown;
assign test_o = dout_state;
//reg transmit = 1;
reg transmit;
assign transmit_o = transmit;
reg [7:0] tx_data;
assign tx_byte_o = tx_data;
reg running;
reg [31:0] ti_packet_sending;
reg [3:0] ram_read_wait;
assign running_o = running;
    parameter EVENT_DATA_SEND_IDLE = 0;
    parameter EVENT_DATA_SEND_HEAD = 1;
    parameter EVENT_DATA_SEND_TI = 2;
    parameter EVENT_DATA_SEND_TRIGTIME = 3;
    parameter EVENT_DATA_SEND_DATASIZE = 4;
    parameter EVENT_DATA_SEND_DATA1 = 5;
    parameter EVENT_DATA_SEND_DATA2 = 6;
    parameter EVENT_DATA_SEND_DATA3 = 7;
    parameter EVENT_DATA_SEND_VDATA = 8;
    parameter header_data_size = 16;  //bit
    parameter ti_data_size = 32; //bit
    parameter data_data_size = 16; //bit
    parameter serial_data_size = 8; //bit
    reg [4:0] dout_state = 0;
    reg [7:0]dout_countdown;

    reg [31:0]tx_data_tmp_4byte;
    reg [15:0]tx_data_tmp_2byte;

    always @(posedge CLK) begin
    if ( !RSTn_i ) begin
      dout_state <= 0;
      raddr <= 0;
      running <= 0;
    end
else begin
    case ( dout_state )

        EVENT_DATA_SEND_IDLE: begin
        tx_data <= 0;
        running <= 0;
        transmit <= 0;
        ram_read_wait <= mem_wait;
        if ( transmit_start && !tx_busy ) begin
        running <= 1;
        bram_send_countdown <= data_length;
        raddr <= raddr_start;
        dout_state <= EVENT_DATA_SEND_HEAD;
        tx_data_tmp_2byte <= header;
        ti_packet_sending <= ti;
        dout_countdown <= 2; //next: 2bytes header transfer

        end
        end

        EVENT_DATA_SEND_HEAD: begin
        transmit <= 0;
        tx_data <= tx_data_tmp_2byte[serial_data_size-1:0];
        if ( !is_transmitting && transmit_timing) begin
        dout_countdown <= dout_countdown - 1;
        transmit <= 1;
        tx_data_tmp_2byte <= {8'h00, tx_data_tmp_2byte[header_data_size-1:serial_data_size]};
        dout_state <= EVENT_DATA_SEND_HEAD;
        if ( dout_countdown == 0 ) begin
        transmit <= 0;
        dout_state <= EVENT_DATA_SEND_TI;
        tx_data_tmp_4byte <= ti_packet_sending;
        tx_data <= tx_data_tmp_4byte[serial_data_size-1:0];
        dout_countdown <= 4; // next: 4bytes TI transefer
        end
        end
        end

        EVENT_DATA_SEND_TI: begin
        transmit <= 0;
        tx_data <= tx_data_tmp_4byte[serial_data_size-1:0];
        if ( !is_transmitting && transmit_timing) begin
        dout_countdown <= dout_countdown - 1;
        transmit <= 1;
        tx_data_tmp_4byte <= {8'h00, tx_data_tmp_4byte[ti_data_size-1:serial_data_size]};
        dout_state = EVENT_DATA_SEND_TI;
        if ( dout_countdown == 0 ) begin
        transmit <= 0;
        dout_state <= EVENT_DATA_SEND_TRIGTIME;
        tx_data_tmp_4byte <= trigtime;
        tx_data <= tx_data_tmp_4byte[serial_data_size-1:0];
        dout_countdown <= 4; // next: 4bytes TI transefer
        end
        end
        end

        EVENT_DATA_SEND_TRIGTIME: begin
        transmit <= 0;
        tx_data <= tx_data_tmp_4byte[serial_data_size-1:0];
        if ( !is_transmitting && transmit_timing) begin
        dout_countdown <= dout_countdown - 1;
        transmit <= 1;
        tx_data_tmp_4byte <= {8'h00, tx_data_tmp_4byte[ti_data_size-1:serial_data_size]};
        dout_state = EVENT_DATA_SEND_TRIGTIME;
        if ( dout_countdown == 0 ) begin
        transmit <= 0;
        dout_state <= EVENT_DATA_SEND_DATASIZE;
        tx_data_tmp_2byte <= datasize;
        tx_data <= tx_data_tmp_2byte[serial_data_size-1:0];
        dout_countdown <= 2; // next: 4bytes TI transefer
        end
        end
        end

        EVENT_DATA_SEND_DATASIZE: begin
        transmit <= 0;
        tx_data <= tx_data_tmp_2byte[serial_data_size-1:0];
        if ( !is_transmitting && transmit_timing) begin
        dout_countdown <= dout_countdown - 1;
        transmit <= 1;
        tx_data_tmp_2byte <= {8'h00, tx_data_tmp_2byte[data_data_size-1:serial_data_size]};
        dout_state = EVENT_DATA_SEND_DATASIZE;
        if ( dout_countdown == 0 ) begin
        transmit <= 0;
        dout_state <= EVENT_DATA_SEND_DATA1;
        tx_data_tmp_2byte <= data1;
        tx_data <= tx_data_tmp_2byte[serial_data_size-1:0];
        dout_countdown <= 2; // next: 4bytes TI transefer
        end
        end
        end

        EVENT_DATA_SEND_DATA1: begin
        transmit <= 0;
        tx_data <= tx_data_tmp_2byte[serial_data_size-1:0];
        if ( !is_transmitting && transmit_timing) begin
        dout_countdown <= dout_countdown - 1;
        transmit <= 1;
        tx_data_tmp_2byte <= {8'h00, tx_data_tmp_2byte[data_data_size-1:serial_data_size]};
        dout_state = EVENT_DATA_SEND_DATA1;
        if ( dout_countdown == 0 ) begin
        transmit <= 0;
        dout_state <= EVENT_DATA_SEND_DATA2;
        tx_data_tmp_2byte <= data2;
        tx_data <= tx_data_tmp_2byte[serial_data_size-1:0];
        dout_countdown <= 2; // next: 4bytes TI transefer
        end
        end
        end

        EVENT_DATA_SEND_DATA2: begin
        transmit <= 0;
        tx_data <= tx_data_tmp_2byte[serial_data_size-1:0];
        if ( !is_transmitting && transmit_timing) begin
        dout_countdown <= dout_countdown - 1;
        transmit <= 1;
        tx_data_tmp_2byte <= {8'h00, tx_data_tmp_2byte[data_data_size-1:serial_data_size]};
        dout_state = EVENT_DATA_SEND_DATA2;
        if ( dout_countdown == 0 ) begin
        transmit <= 0;
        dout_state <= EVENT_DATA_SEND_DATA3;
        tx_data_tmp_2byte <= data3;
        tx_data <= tx_data_tmp_2byte[serial_data_size-1:0];
        dout_countdown <= 2; // next: 4bytes TI transefer
        end
        end
        end

        EVENT_DATA_SEND_DATA3: begin
        transmit <= 0;
        tx_data <= tx_data_tmp_2byte[serial_data_size-1:0];
        if ( !is_transmitting && transmit_timing) begin
        dout_countdown <= dout_countdown - 1;
        transmit <= 1;
        tx_data_tmp_2byte <= {8'h00, tx_data_tmp_2byte[data_data_size-1:serial_data_size]};
        dout_state = EVENT_DATA_SEND_DATA3;
        if ( dout_countdown == 0 ) begin
        transmit <= 0;
        dout_state <= EVENT_DATA_SEND_VDATA;
        tx_data_tmp_2byte <= vdata;
        tx_data <= tx_data_tmp_2byte[serial_data_size-1:0];
        dout_countdown <= 2; // next: 4bytes TI transefer
        end
        end
        end

        EVENT_DATA_SEND_VDATA: begin
        transmit <= 0;
        tx_data <= tx_data_tmp_2byte[serial_data_size-1:0];
        if ( !is_transmitting && transmit_timing ) begin
        dout_countdown <= dout_countdown - 1;
        transmit <= 1;
        tx_data_tmp_2byte <= {8'h00, tx_data_tmp_2byte[data_data_size-1:serial_data_size]};
        dout_state <= EVENT_DATA_SEND_VDATA;
        if ( dout_countdown == 0 && bram_send_countdown ) begin
        transmit <= 0;
        dout_countdown <= 2;
        raddr <= raddr + 1;
        bram_send_countdown <= bram_send_countdown - 1;
        tx_data_tmp_2byte <= vdata;
        tx_data <= tx_data_tmp_2byte[serial_data_size-1:0];
        ram_read_wait <= ram_read_wait - 1;
        if ( ram_read_wait == 0 ) begin
        ram_read_wait <= mem_wait;
        dout_state <= EVENT_DATA_SEND_VDATA;
        end
        end
        else if ( bram_send_countdown == 0 ) begin
        transmit <= 0;
        bram_send_countdown <= data_length;
        tx_data <= 0;
        dout_state <= EVENT_DATA_SEND_IDLE;
        end
        end
        end

        endcase
        end
        end


endmodule
