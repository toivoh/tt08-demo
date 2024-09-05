`default_nettype none
`include "common.vh"
`include "synth_common.vh"
`include "common_generated.vh"

module demo_top #( parameter FULL_FPS=1, A_BITS=11, OSHIFT=6, OCT_BITS=3, PWM_BITS=`PROG_ADDR_BITS, Y_STEPS=525, Y_SAT_BITS=9, FRAME_COUNTER_BITS_SLOW=14 ) (
		input wire clk, reset,
		input wire advance_frame,
		input wire [`EXT_CONTROL_BITS-1:0] ext_control,

		output wire enable,
		output wire [3*`FINAL_COLOR_CHANNEL_BITS-1:0] rgb,
		output wire hsync, vsync, new_frame,
		output wire audio_out
	);

	localparam SLOW_SOUND = FULL_FPS;

	localparam X_FINE_PERIOD = SLOW_SOUND ? 100 : 50;
	localparam X_COARSE_BITS = SLOW_SOUND ? 3 : 4;
	localparam FRAME_COUNTER_BITS = FRAME_COUNTER_BITS_SLOW + (SLOW_SOUND - 1);

	// Graphics
	// ========

	wire pause = ext_control[`EC_PAUSE];
	wire [$clog2(X_FINE_PERIOD)-1:0] x_fine;
	wire [X_COARSE_BITS-1:0] x_coarse;
	wire [Y_SAT_BITS-1:0] y_sat, y_wrap;
	wire [FRAME_COUNTER_BITS-1:0] frame_counter;
	wire raise_drum;
	wire show_audio;
	wire [`PLAYER_CONTROL_BITS-1:0] player_control;
	graphics_top #(
		.X_FINE_PERIOD(X_FINE_PERIOD), .X_COARSE_BITS(X_COARSE_BITS), .Y_STEPS(Y_STEPS), .Y_SAT_BITS(Y_SAT_BITS), .FRAME_COUNTER_BITS(FRAME_COUNTER_BITS),
		.FULL_FPS(SLOW_SOUND)
	) vtop(
		.clk(clk), .reset(reset), .advance_frame(advance_frame), .pause(pause),
		.audio_out(audio_out), .raise_drum(raise_drum), .show_audio(show_audio), .player_control(player_control),
		.rgb_out(rgb), .hsync(hsync), .vsync(vsync), .new_frame(new_frame),
		.enable(enable), .x_fine(x_fine), .x_coarse(x_coarse), .y_sat(y_sat), .y_wrap(y_wrap), .raw_frame_counter(frame_counter)
	);


	// Synth
	// =====

	localparam SAMPLE_COUNTER_BITS = FRAME_COUNTER_BITS+Y_SAT_BITS+X_COARSE_BITS;
	wire [SAMPLE_COUNTER_BITS-1:0] sample_counter = {frame_counter, y_sat, x_coarse};

	wire [`PROG_ADDR_BITS-1:0] program_addr = SLOW_SOUND ? x_fine : {x_fine, enable};
	wire [2**OCT_BITS-1-1:0] oct_counter = {y_wrap, x_coarse};
	wire [A_BITS+2**`SHIFT_COUNT_BITS-1-1:0] detune_counter = sample_counter >> `MIN_OC_SHIFT;

	wire signed [A_BITS-1:0] out_sample;
	player #(.A_BITS(A_BITS), .OSHIFT(OSHIFT), .OCT_BITS(OCT_BITS), .TRACK_LOG2_WAIT(A_BITS+8), .SAMPLE_COUNTER_BITS(SAMPLE_COUNTER_BITS)) player_inst (
		.clk(clk), .reset(reset), .enable(SLOW_SOUND ? enable : 1'b1),
		.program_addr(program_addr), .oct_counter(oct_counter), .detune_counter(detune_counter), .sample_counter(sample_counter),
		.raise_drum(raise_drum), .visual(show_audio), .control(player_control), .ext_control(ext_control),
		.out(out_sample)
	);

	wire [PWM_BITS-1:0] pwm_counter = program_addr;
	wire [PWM_BITS-1:0] unsigned_sample = out_sample[PWM_BITS-1:0];
	//assign audio_out = (unsigned_sample > pwm_counter);
	assign audio_out = (unsigned_sample > pwm_counter) ^ (!sample_counter[0]);
endmodule : demo_top
