`default_nettype none
`include "common.vh"

module demo_top #( parameter Y_STEPS=525, Y_SAT_BITS=9, FRAME_COUNTER_BITS=11 ) (
		input wire clk, reset,

		output wire [5:0] rgb222,
		output wire hsync, vsync, new_frame,
		output wire audio_out
	);

	localparam X_FINE_PERIOD = 100;
	localparam X_COARSE_BITS = 3;

	wire enable;
	wire [$clog2(X_FINE_PERIOD)-1:0] x_fine;
	wire [X_COARSE_BITS-1:0] x_coarse;
	wire [Y_SAT_BITS-1:0] y_sat, y_wrap;
	wire [FRAME_COUNTER_BITS-1:0] frame_counter;
	graphics_top #(.X_FINE_PERIOD(X_FINE_PERIOD), .X_COARSE_BITS(X_COARSE_BITS), .Y_STEPS(Y_STEPS), .Y_SAT_BITS(Y_SAT_BITS), .FRAME_COUNTER_BITS(FRAME_COUNTER_BITS)) vtop(
		.clk(clk), .reset(reset),
		.rgb_out(rgb222), .hsync(hsync), .vsync(vsync), .new_frame(new_frame),
		.enable(enable), .x_fine(x_fine), .x_coarse(x_coarse), .y_sat(y_sat), .y_wrap(y_wrap), .frame_counter(frame_counter)
	);

	assign audio_out = 0;
endmodule : demo_top
