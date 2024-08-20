`default_nettype none
`include "common.vh"


module full_sine_table #(parameter COSAPPR_BITS=4) (
		input wire [`SINE_IN_BITS+2-1:0] phase,
		output wire signed [`SINE_OUT_BITS+1-1:0] y,
		output wire [COSAPPR_BITS-1:0] cosappr
	);

	// Invert input if needed
	wire [`SINE_IN_BITS-1:0] sine_tab_x = phase[`SINE_IN_BITS-1:0] ^ (phase[`SINE_IN_BITS] ? '1 : '0);

	wire [`SINE_OUT_BITS-1:0] sine_tab_y;
	sine_table tab(.x(sine_tab_x), .y(sine_tab_y));

	// Invert output if needed
	wire invert_y = phase[`SINE_IN_BITS + 1];
	wire [`SINE_OUT_BITS+1-1:0] y0 = sine_tab_y;
	assign y = y0 ^ (invert_y ? '1 : '0);
	assign cosappr = ~sine_tab_x[`SINE_IN_BITS-1 -: COSAPPR_BITS];
endmodule


module graphics_renderer #(parameter NUM_WAVES=3, RESTART_COUNTER_BITS=2) (
		input wire clk, reset,
		input wire restart,
		input wire [RESTART_COUNTER_BITS-1:0] restart_counter,

		input wire initialize_phase,
		input wire [`PHASE_BITS-1:0] phase_init,

		output wire [$clog2(NUM_WAVES)-1:0] curr_wave_index,
		input wire signed [`DPHASE_BITS-1:0] dphase, // dphase = dphases[curr_wave_index]

		input wire [$clog2(NUM_WAVES)-1:0] sine_shifter_shr,
		output wire signed [`SINE_OUT_BITS+1+2**$clog2(NUM_WAVES)-1-1:0] sine_shifter_out,

		output wire [`COLOR_BITS-1:0] output_color
	);

	localparam WAVE_INDEX_BITS = $clog2(NUM_WAVES);

	localparam DPHASE_BITS = `DPHASE_BITS;
	localparam PHASE_BITS = `PHASE_BITS;

	localparam ZG_BITS = `ZG_BITS;
	localparam COSAPPR_BITS = `COSAPPR_BITS;


	genvar i;


	wire write_zg;

	// Phases
	// ======
	reg [WAVE_INDEX_BITS-1:0] wave_index;
	(* mem2reg *) reg [PHASE_BITS-1:0] phases[NUM_WAVES];

	//assign curr_wave_index = wave_index;
	assign curr_wave_index = restart ? restart_counter[WAVE_INDEX_BITS-1:0] : wave_index;

	wire last_wave = (wave_index == NUM_WAVES - 1);
	wire [WAVE_INDEX_BITS-1:0] next_wave_index = restart || last_wave ? 0 : wave_index + !last_wave;
	always_ff @(posedge clk) begin
		wave_index <= next_wave_index;
	end

	wire [PHASE_BITS-1:0] curr_phase = phases[curr_wave_index];
	wire [PHASE_BITS-1:0] next_phase = curr_phase + dphase;

	generate
		for (i = 0; i < NUM_WAVES; i++) begin
			always_ff @(posedge clk) begin
				if (restart) begin
					if (initialize_phase && restart_counter[WAVE_INDEX_BITS-1:0] == i) phases[i] <= phase_init;
				end else begin
					// can use wave_index instead of curr_wave_index since restart is low here
					if (i == wave_index) phases[i] <= next_phase; // TODO: clock gate
				end
			end
		end
	endgenerate


	// zg
	// ==
	wire zg_done;

	localparam MAP_IN_BITS  = `SINE_IN_BITS  + 2;
	localparam MAP_OUT_BITS = `SINE_OUT_BITS + 1;
	localparam MAP_OUTPUT_SHIFT_BITS = 2;

	localparam COSAPPR_TERM_BITS = COSAPPR_BITS - 2;

	reg zg_valid;
	assign zg_done = zg_valid;
	reg [ZG_BITS-1:0] zg_acc, zg; // TODO: clock gate, shared n-latches
	reg [COSAPPR_BITS-1:0] cosappr_acc, cosappr; // TODO: clock gate, shared n-latches

	wire signed [MAP_OUT_BITS-1:0] sine_tab_y;
	wire [COSAPPR_TERM_BITS-1:0] delta_cosappr;
	full_sine_table #(.COSAPPR_BITS(COSAPPR_TERM_BITS)) tab(.phase(curr_phase[PHASE_BITS-1 -: MAP_IN_BITS]), .y(sine_tab_y), .cosappr(delta_cosappr));


//	wire signed [ZG_BITS-1:0] delta_zg = sine_tab_y >>> wave_index;

	// TODO: remove shift count mux if unused
	// can use wave_index instead of curr_wave_index since restart is low when we do:
	wire [WAVE_INDEX_BITS-1:0] sine_shifter_shr_count = restart ? sine_shifter_shr : wave_index;
	localparam EXTRA_SINE_SHIFTER_BITS = 2**WAVE_INDEX_BITS - 1;
	localparam SINE_SHIFTER_BITS = MAP_OUT_BITS + EXTRA_SINE_SHIFTER_BITS;

	wire signed [SINE_SHIFTER_BITS-1:0] sine_shifter_in = {sine_tab_y, {EXTRA_SINE_SHIFTER_BITS{1'b0}}};
	//wire signed [SINE_SHIFTER_BITS-1:0] sine_shifter_out = sine_shifter_in >>> sine_shifter_shr_count;
	assign sine_shifter_out = sine_shifter_in >>> sine_shifter_shr_count;
	wire signed [ZG_BITS-1:0] delta_zg = sine_shifter_out >>> EXTRA_SINE_SHIFTER_BITS;



	wire zg_acc_mask, write_zg_acc;
	assign zg_acc_mask = (wave_index != 0); // can use wave_index instead of curr_wave_index since don't care about behavior during restart phase
	assign write_zg_acc = !last_wave;
	assign write_zg = last_wave;

	wire [ZG_BITS-1:0] zg_sum = (zg_acc_mask ? zg_acc : (1 << (ZG_BITS-1))) + delta_zg;
	wire [COSAPPR_BITS-1:0] cosappr_sum = (zg_acc_mask ? cosappr_acc : 0) + delta_cosappr;

	always_ff @(posedge clk) begin
		if (restart) zg_valid <= 0;
		else if (write_zg) zg_valid <= 1;
		else if (zg_done) zg_valid <= 0;

		if (write_zg_acc) zg_acc <= zg_sum;
		if (write_zg)     zg     <= zg_sum;
		if (write_zg_acc) cosappr_acc <= cosappr_sum;
		if (write_zg)     cosappr     <= cosappr_sum;
	end


	// Output
	//=======

	wire [`COLOR_CHANNEL_BITS-1:0] r, g, b;
	//assign g = ~zg[ZG_BITS-1 -: `COLOR_CHANNEL_BITS];
	assign g = cosappr[COSAPPR_BITS-1 -: `COLOR_CHANNEL_BITS];

	wire [`COLOR_CHANNEL_BITS+1-1:0] l = ~zg[ZG_BITS-1 -: `COLOR_CHANNEL_BITS+1];
	wire bright = l[`COLOR_CHANNEL_BITS];
	//assign r = bright ? l : '0;
	wire [`COLOR_CHANNEL_BITS-1:0] r0 = bright ? l : '0;
	assign r = (r0 < g) ? r0 : g;

	assign b = ~zg[ZG_BITS-1 -: `COLOR_CHANNEL_BITS];

	wire [`COLOR_BITS-1:0] color = {r, g, b};

	assign output_color = color;
endmodule : graphics_renderer


module graphics_top #(
		parameter X_BITS=10, Y_BITS=9, X_SUB_BITS=1, NUM_WAVES=3, X_FINE_PERIOD=100, X_COARSE_BITS=3, Y_STEPS=525, Y_SAT_BITS=9,
		FRAME_COUNTER_BITS=10, LOG2_GRAPHICS_PERIOD=11
	) (
		input wire clk, reset,

		output wire [5:0] rgb_out,
		output wire hsync, vsync,
//		output reg hsync, vsync,
		output wire new_frame,

		output wire enable,
		output wire [$clog2(X_FINE_PERIOD)-1:0] x_fine,
		output wire [X_COARSE_BITS-1:0] x_coarse,
		output wire [Y_SAT_BITS-1:0] y_sat, y_wrap,
		output wire [FRAME_COUNTER_BITS-1:0] frame_counter
	);

	localparam RESTART_COUNTER_BITS = 3; // Must be <= 5

	localparam WAVE_INDEX_BITS = $clog2(NUM_WAVES);
	localparam MAP_OUT_BITS = `SINE_OUT_BITS + 1;
	localparam EXTRA_SINE_SHIFTER_BITS = 2**WAVE_INDEX_BITS - 1;
	localparam SINE_SHIFTER_BITS = MAP_OUT_BITS + EXTRA_SINE_SHIFTER_BITS;


	genvar i;


	// Raster scan
	// ===========

	reg [FRAME_COUNTER_BITS-1:0] r_frame_counter;
	assign frame_counter = r_frame_counter;

	reg [X_SUB_BITS-1:0] xfrac_counter;
	always @(posedge clk) begin
		if (reset) xfrac_counter <= 0;
		else xfrac_counter <= xfrac_counter + 1;
	end
	assign enable = (xfrac_counter == '1);

	wire [X_BITS-1:0] x;
	wire [Y_BITS-1:0] y;
	wire h_active, hsync0;
	wire new_line;
	wire vsync0;
	wire active;
	raster_scan2 #(.X_FINE_PERIOD(X_FINE_PERIOD), .X_COARSE_BITS(X_COARSE_BITS), .Y_STEPS(Y_STEPS), .Y_SAT_BITS(Y_SAT_BITS)) rs(
		.clk(clk), .reset(reset), .enable(enable),

		.x(x), .x_coarse(x_coarse), .x_fine(x_fine),
		.h_active(h_active), .hsync(hsync0),
		.new_line(new_line),

		.y_wrap(y_wrap), .y_sat(y_sat),
		.vsync(vsync0),
		.new_frame(new_frame),

		.active(active)
	);

	assign y = y_wrap;
	assign vsync = vsync0;
	assign hsync = hsync0;

	// Graphics
	// =====

	(* mem2reg *) reg signed [`DPHASE_BITS-1:0] dphases[NUM_WAVES];

	wire dphase_we = restart && restart_counter[RESTART_COUNTER_BITS-1:WAVE_INDEX_BITS] == 0;
	wire [WAVE_INDEX_BITS-1:0] sine_shifter_shr = ~restart_counter;

	generate
		for (i = 0; i < NUM_WAVES; i++) begin
			always_ff @(posedge clk) begin
				if (dphase_we && restart_counter[WAVE_INDEX_BITS-1:0] == i+1) dphases[i] <= sine_shifter_out[SINE_SHIFTER_BITS-1 -: `DPHASE_BITS];
			end
		end
	endgenerate



	wire restart = (x_coarse == '0 && x_fine[$clog2(X_FINE_PERIOD)-1:RESTART_COUNTER_BITS] == '0);
	wire [RESTART_COUNTER_BITS-1:0] restart_counter = x_fine[RESTART_COUNTER_BITS-1:0];

	wire [$clog2(NUM_WAVES)-1:0] curr_wave_index;
	wire signed [`DPHASE_BITS-1:0] dphase = dphases[curr_wave_index];

	wire initialize_phase = 1;
	wire [1:0] phase_init_shl = restart_counter + dphase_we;

	wire [2:0] phase_shl = restart_counter[2:0];

	wire [`PHASE_BITS+1-1:0] pt1 = {frame_counter, {(`PHASE_BITS-LOG2_GRAPHICS_PERIOD){1'b0}}};
	wire [`PHASE_BITS+1-1:0] pt2 = phase_shl[0] ? ~pt1 << 1 : pt1; // reverse sign for every other shift count
	wire [`PHASE_BITS+1-1:0] phase_init0 = pt2 << (phase_shl & ~1);


	localparam Y_SHL_BITS = `PHASE_BITS-Y_BITS-2;
	wire [`PHASE_BITS-1:0] phase_init = phase_init0 + (dphase_we ? {y, {(Y_SHL_BITS){1'b0}}} : '0);
	wire [Y_BITS-1:0] y_moved = phase_init >> Y_SHL_BITS; 

	wire signed [SINE_SHIFTER_BITS-1:0] sine_shifter_out;
	wire [`COLOR_BITS-1:0] color;
	graphics_renderer #(.NUM_WAVES(NUM_WAVES), .RESTART_COUNTER_BITS(RESTART_COUNTER_BITS)) pipeline(
		.clk(clk), .reset(reset),
		.restart(restart), .restart_counter(restart_counter),
		.initialize_phase(initialize_phase), .phase_init(phase_init),
		.curr_wave_index(curr_wave_index),
		.dphase(dphase),
		.sine_shifter_shr(sine_shifter_shr), .sine_shifter_out(sine_shifter_out),
		.output_color(color)
	);


	// Dithering
	// =========
	wire [`COLOR_DITHER_BITS-1:0] dither = {y[0]^x[1], x[0]};
	generate
		for (i = 0; i < 3; i++) begin
			wire [`COLOR_CHANNEL_BITS+1-1:0] dither_sum = color[(i+1)*`COLOR_CHANNEL_BITS-1 -: `COLOR_CHANNEL_BITS] + dither;
			wire [`FINAL_COLOR_CHANNEL_BITS-1:0] channel = dither_sum[`COLOR_CHANNEL_BITS] ? '1 : dither_sum[`COLOR_CHANNEL_BITS-1 -: `FINAL_COLOR_CHANNEL_BITS];
			//wire channel = color[(i+1)*`COLOR_CHANNEL_BITS-1 -: `FINAL_COLOR_CHANNEL_BITS];
			assign rgb_out[(i+1)*`FINAL_COLOR_CHANNEL_BITS-1 -: `FINAL_COLOR_CHANNEL_BITS] = active ? channel : '0;
		end
	endgenerate


	always @(posedge clk) begin
		if (reset) r_frame_counter <= 0;
		else r_frame_counter <= frame_counter + new_frame;
	end
endmodule
