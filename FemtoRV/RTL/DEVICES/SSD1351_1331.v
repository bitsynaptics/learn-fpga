// femtorv32, a minimalistic RISC-V RV32I core
//       Bruno Levy, 2020-2021
//
// This file: driver for SSD1351 and SSD1331 OLED display
// Reference: https://www.crystalfontz.com/controllers/SolomonSystech/SSD1351/

//
// TODO: we could use wmask to write directly 16 bits or 32 bits of data
//       (we could even have a 'fast clear' option that writes a number
//        of zeroes).

`ifdef NRV_IO_SSD1331
`define NRV_IO_SSD1351_1331
`endif

`ifdef NRV_IO_SSD1351
`define NRV_IO_SSD1351_1331
`endif

module SSD1351_clk #(
   parameter width=1
)(
   input  wire clk,               // input system clock
   output wire CLK,               // SSD1351 clock
   output wire CLK_falling_edge   // pulses at each falling edge of CLK		   
);
   reg [width-1:0] slow_cnt;
   always @(posedge clk) begin
      slow_cnt <= slow_cnt + 1;
   end
   assign CLK = slow_cnt[width-1];
   assign CLK_falling_edge = (slow_cnt == (1 << width)-1);
endmodule   

module SSD1351(
    input wire 	      clk,       // system clock
    input wire 	      wstrb,     // write strobe (use one of sel_xxx to select dest)
    input wire 	      sel_cntl,  // wdata[0]: !CS;  wdata[1]: RST
    input wire 	      sel_cmd,   // send 8-bits command to display
    input wire 	      sel_dat,   // send 8-bits data to display
    input wire 	      sel_dat16, // send 16-bits data to display

    input wire [31:0] wdata,    // data to be written

    output wire       wbusy,    // asserted if the driver is busy sending data

                           // SSD1351 pins	       
    output 	      DIN, // data in
    output 	      CLK, // clock
    output reg 	      CS,  // chip select (active low)
    output reg 	      DC,  // data (high) / command (low)
    output reg 	      RST,  // reset (active low)
    output            PMODEN,
    output            VCCEN
);
  
   initial begin
      DC  = 1'b0;
      RST = 1'b0;
      CS  = 1'b1;
   end

   assign PMODEN = 1'b1;
   assign VCCEN  = 1'b1;

   /********* The clock ****************************************************/
   // Note: SSD1351 expects the raising edges of the clock in the middle of
   // the data bits.
   // TODO: try to have a 'waveform' instead, that is shifted (simpler and
   //       more elegant).
   // Page 52 of the doc: 4-wire SPI timing:
   //   Unclear what 'Clock Cycle Time' (220 ns) means,
   //   Clock Low Time (20ns) + Clock High Time (20ns) = 40ns
   //   max freq = 1/(40ns) = 25 MHz
   //   experimentally, seems to work up to 30 Mhz (but not more)
   
   wire CLK_falling_edge;
   
   generate
      if(`NRV_FREQ <= 60) begin           // Divide by 2-> 30 MHz
	 SSD1351_clk #(
            .width(1)
         )slow_clk(
            .clk(clk),
            .CLK(CLK),
            .CLK_falling_edge(CLK_falling_edge)
	);
      end else if(`NRV_FREQ <= 120) begin // Divide by 4
	 SSD1351_clk #(
            .width(2)
         )slow_clk(
            .clk(clk),
            .CLK(CLK),
            .CLK_falling_edge(CLK_falling_edge)
         );
      end else begin                      // Divide by 8
	 SSD1351_clk #(
            .width(3)
         )slow_clk(
            .clk(clk),
            .CLK(CLK),
            .CLK_falling_edge(CLK_falling_edge)
         );
      end
    endgenerate

   // Currently sent bit, 1-based index
   // (0000 config. corresponds to idle)
   reg[4:0]  bitcount = 5'b0000;
   reg[15:0] shifter  = 0;
   wire      sending  = (bitcount != 0);

   assign DIN = shifter[15];
   assign wbusy = sending;

   /*************************************************************************/
   
   always @(posedge clk) begin
      if(wstrb) begin
	 if(sel_cntl) begin
	    CS  <= !wdata[0];
	    RST <= wdata[1];
	 end
	 if(sel_cmd) begin
	    RST <= 1'b1;
	    DC <= 1'b0;
	    shifter <= {wdata[7:0],8'b0};
	    bitcount <= 8;
	    CS  <= 1'b1;
	 end
	 if(sel_dat) begin
 	    RST <= 1'b1;
	    DC <= 1'b1;
	    shifter <= {wdata[7:0],8'b0};
	    bitcount <= 8;
	    CS  <= 1'b1;
	 end
	 if(sel_dat16) begin
 	    RST <= 1'b1;
	    DC <= 1'b1;
	    shifter <= wdata[15:0];
	    bitcount <= 16;
	    CS  <= 1'b1;
	 end
      end else begin 
	 // detect falling edge of slow_clk
	 if(CLK_falling_edge) begin 
	    if(sending) begin
	       if(CS) begin    // first tick activates CS (low)
		  CS <= 1'b0;
	       end else begin  // shift on falling edge
		  bitcount <= bitcount - 5'd1;
		  shifter <= {shifter[14:0], 1'b0};
	       end
	    end else begin     // last tick deactivates CS (high) 
	       CS  <= 1'b1;  
	    end
	 end
      end
   end
endmodule
