/*
 * Copyright (c) 2024 Toivo Henningsson
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

`include "common.vh"
`include "synth_common.vh"
`include "common_generated.vh"

module tt_um_toivoh_demo (
		input  wire [7:0] ui_in,    // Dedicated inputs
		output wire [7:0] uo_out,   // Dedicated outputs
		input  wire [7:0] uio_in,   // IOs: Input path
		output wire [7:0] uio_out,  // IOs: Output path
		output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
		input  wire       ena,      // always 1 when the design is powered, so you can ignore it
		input  wire       clk,      // clock
		input  wire       rst_n     // reset_n - low to reset
	);

	reg [7:0] ui_in_reg;
	reg rst_n_reg;
	always @(posedge clk) rst_n_reg <= rst_n;

	//wire reset = !rst_n_reg;
	wire reset = !rst_n;

	wire [`EXT_CONTROL_BITS-1:0] ext_control = ui_in;
	wire advance_frame = ui_in[7];

	wire enable;
	wire [5:0] rgb;
	wire hsync, vsync, new_frame;
	wire audio_out;
	demo_top #(.FULL_FPS(1)) dtop(
		.clk(clk), .reset(reset), .advance_frame(advance_frame), .ext_control(ext_control),
		.enable(enable),
		.rgb(rgb), .hsync(hsync), .vsync(vsync), .new_frame(new_frame),
		.audio_out(audio_out)
	);

	wire [`FINAL_COLOR_CHANNEL_BITS-1:0] r, g, b;
	assign {r, g, b} = rgb;

	wire [7:0] uo_out0, uio_out0;
	reg [7:0] uo_out1, uio_out1;

	assign uo_out0 = {
		hsync,
		b[`FINAL_COLOR_CHANNEL_BITS-2],
		g[`FINAL_COLOR_CHANNEL_BITS-2],
		r[`FINAL_COLOR_CHANNEL_BITS-2],
		vsync,
		b[`FINAL_COLOR_CHANNEL_BITS-1],
		g[`FINAL_COLOR_CHANNEL_BITS-1],
		r[`FINAL_COLOR_CHANNEL_BITS-1]
	};
	assign uio_out0[7] = audio_out & !ext_control[`EC_PAUSE];
	assign uio_oe[7] = 1'b1;
	assign uio_out0[6:0] = '0;
	assign uio_oe[6:0] = '0;

	always @(posedge clk) begin
		if (enable) begin
			uo_out1 <= uo_out0;
			uio_out1 <= uio_out0;
		end
		ui_in_reg <= ui_in;
	end
	assign uo_out = uo_out1;
	assign uio_out = uio_out1;

	// List all unused inputs to prevent warnings
	wire _unused = &{ena, rst_n, ui_in, uio_in};
endmodule
