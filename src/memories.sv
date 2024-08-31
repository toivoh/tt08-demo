/*
 * Copyright (c) 2024 Toivo Henningsson
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

`include "synth_common.vh"
`include "common_generated.vh"



`ifdef NOT_DEFINED

module mux4 #( parameter LOG2_BITS_IN=5 ) (
		input wire [1:0] addr,
		input wire [2**LOG2_BITS_IN-1:0] data_in,
		output wire [2**(LOG2_BITS_IN-2)-1:0] data_out
	);
	genvar i;
	generate
		for (i = 0; i < 2**(LOG2_BITS_IN-2); i++) begin
			wire [3:0] data_in_i = data_in[4*i+3 -: 4];
			wire data_out_i;
			//assign data_out[i] = data_in_i[addr];
			sky130_fd_sc_hd__mux4_1 mux4_inst(
				.A0(data_in_i[0]), .A1(data_in_i[1]), .A2(data_in_i[2]), .A3(data_in_i[3]),
				.S0(addr[0]), .S1(addr[1]),
				.X(data_out_i)
			);
			assign data_out[i] = data_out_i;

		end
	endgenerate
endmodule

module mem_mux #( parameter ADDR_BITS=5 ) (
		input wire [ADDR_BITS-1:0] addr,
		input wire [2**ADDR_BITS-1:0] data_in,
		output wire data_out
	);

	assign data_out = data_in[addr];
/*
	wire [2**(ADDR_BITS-2)-1:0] data1;
	wire [2**(ADDR_BITS-4)-1:0] data2;
	mux4 #( .LOG2_BITS_IN(ADDR_BITS  ) ) mux4_inst1( .addr(addr[1:0]), .data_in(data_in), .data_out(data1) );
	mux4 #( .LOG2_BITS_IN(ADDR_BITS-2) ) mux4_inst2( .addr(addr[3:2]), .data_in(data1  ), .data_out(data2) );
	assign data_out = data2[addr[ADDR_BITS-1:4]];
*/
endmodule


module np_latch_ram #( parameter ADDR_BITS=2, DATA_BITS=8 ) ( // TODO: non-power-of-two sizes?
		input wire clk, reset,

		input wire we,
		input wire [ADDR_BITS-1:0] addr,
		input wire [DATA_BITS-1:0] wdata,
		output wire [DATA_BITS-1:0] rdata
	);

	localparam NUM_ADDR = 2**ADDR_BITS;


	genvar i;
	genvar j;


	// Demux
	// -----
	wire [NUM_ADDR-1:0] data_we;
	wire [NUM_ADDR-1:0] gclk;

	generate
		for (j = 0; j < NUM_ADDR; j++) begin
			assign data_we[j] = (addr == j) && we;

			`ifndef BUFFER_CLOCK_GATE
			sky130_fd_sc_hd__dlclkp_1 clock_gate(   .CLK(clk),  .GATE(data_we[j]), .GCLK(gclk[j]) );
			`else
			wire _gclk;
			sky130_fd_sc_hd__dlclkp_1 clock_gate( .CLK(clk), .GATE(data_we[j]), .GCLK(_gclk) );
			sky130_fd_sc_hd__clkbuf_8 clock_buffer( .A(_gclk), .X(gclk[j]) );
			`endif
		end
	endgenerate

	// Memory array
	// ------------
	wire [DATA_BITS-1:0] data[NUM_ADDR];

	generate
		wire [DATA_BITS-1:0] wdata2;
		for (i = 0; i < DATA_BITS; i++) begin
			sky130_fd_sc_hd__dlxtn_1 n_latch( .GATE_N(clk), .D(wdata[i]), .Q(wdata2[i]));
		end

		for (j = 0; j < NUM_ADDR; j++) begin
			for (i = 0; i < DATA_BITS; i++) begin
				sky130_fd_sc_hd__dlxtp_1 p_latch(.GATE(gclk[j]), .D(wdata2[i]), .Q(data[j][i]));
			end
		end
	endgenerate

	// Mux
	// ---
	//assign rdata = data[addr];
	generate
		for (i = 0; i < DATA_BITS; i++) begin
			wire [NUM_ADDR-1:0] data_in;
			for (j = 0; j < NUM_ADDR; j++) begin
				assign data_in[j] = data[j][i];
			end
			mem_mux #( .ADDR_BITS(ADDR_BITS) ) mux_inst ( .addr(addr), .data_in(data_in), .data_out(rdata[i]) );
			//mux4 #( .LOG2_BITS_IN(ADDR_BITS) ) mux4_inst1( .addr(addr[1:0]), .data_in(data_in), .data_out(rdata[i]) ); // only for ADDR_BITS=2!
		end
	endgenerate
endmodule : np_latch_ram

`endif


module np_latch_registers #( parameter NUM_REGS=2, DATA_BITS=8, USE_ALU_REG_PRUNING=0 ) (
		input wire clk, reset,

		input wire [NUM_REGS-1:0] we,
		//input wire [$clog2(NUM_REGS)-1:0] addr,
		input wire [DATA_BITS-1:0] wdata,
		//output wire [DATA_BITS-1:0] rdata
		output wire [NUM_REGS*DATA_BITS-1:0] all_data
	);

	localparam ADDR_BITS = $clog2(NUM_REGS);


	genvar i;
	genvar j;


	// Demux
	// -----
	wire [NUM_REGS-1:0] data_we;
	wire [NUM_REGS-1:0] gclk;

	generate
		for (j = 0; j < NUM_REGS; j++) begin
			//assign data_we[j] = (addr == j) && we;
			assign data_we[j] = we[j];

			`ifndef BUFFER_CLOCK_GATE
			sky130_fd_sc_hd__dlclkp_1 clock_gate(   .CLK(clk),  .GATE(data_we[j]), .GCLK(gclk[j]) );
			`else
			wire _gclk;
			sky130_fd_sc_hd__dlclkp_1 clock_gate( .CLK(clk), .GATE(data_we[j]), .GCLK(_gclk) );
			sky130_fd_sc_hd__clkbuf_8 clock_buffer( .A(_gclk), .X(gclk[j]) );
			`endif
		end
	endgenerate

	// Memory array
	// ------------
	wire [DATA_BITS-1:0] data[NUM_REGS];

	wire [DATA_BITS-1:0] wdata2;
	generate
		for (i = 0; i < DATA_BITS; i++) begin
			sky130_fd_sc_hd__dlxtn_1 n_latch( .GATE_N(clk), .D(wdata[i]), .Q(wdata2[i]));
		end

		for (j = 0; j < NUM_REGS; j++) begin
			for (i = 0; i < DATA_BITS; i++) begin
//			for (i = 0; i < (USE_ALU_REG_PRUNING && (j == `S_OUTPUT_ACC || j == `S_OUTPUT) ? `PROG_ADDR_BITS : DATA_BITS); i++) begin
				sky130_fd_sc_hd__dlxtp_1 p_latch(.GATE(gclk[j]), .D(wdata2[i]), .Q(data[j][i]));

				assign all_data[DATA_BITS*j + i] = data[j][i];
			end
			/*
			for (i = USE_ALU_REG_PRUNING && (j == `S_OUTPUT_ACC || j == `S_OUTPUT) ? `PROG_ADDR_BITS : DATA_BITS; i < DATA_BITS; i++) begin
				assign all_data[DATA_BITS*j + i] = 0; // TODO: 1'bX?
			end
			*/
		end
	endgenerate

/*
	// Mux
	// ---
	//assign rdata = data[addr];
	generate
		for (i = 0; i < DATA_BITS; i++) begin
			wire [NUM_REGS-1:0] data_in;
			for (j = 0; j < NUM_REGS; j++) begin
				assign data_in[j] = data[j][i];
			end
			mem_mux #( .ADDR_BITS(ADDR_BITS) ) mux_inst ( .addr(addr), .data_in(data_in), .data_out(rdata[i]) );
			//mux4 #( .LOG2_BITS_IN(ADDR_BITS) ) mux4_inst1( .addr(addr[1:0]), .data_in(data_in), .data_out(rdata[i]) ); // only for ADDR_BITS=2!
		end
	endgenerate
	*/
endmodule : np_latch_registers
