`default_nettype none
`include "common.vh"
`include "synth_common.vh"


module full_sine_table #(parameter COSAPPR_BITS=4) (
		input wire [`SINE_IN_BITS+2-1:0] phase,
		input sharp, semi_sharp,

		output wire signed [`SINE_OUT_BITS+1-1:0] y,
		output wire [COSAPPR_BITS-1:0] cosappr
	);

	wire use_sharp = sharp && (!semi_sharp || phase[`SINE_IN_BITS + 1]);
	//wire use_sharp = sharp;


	// Invert input if needed
	wire [`SINE_IN_BITS-1:0] sine_tab_x = phase[`SINE_IN_BITS-1:0] ^ (phase[`SINE_IN_BITS] ^ use_sharp ? '1 : '0);

	wire [`SINE_OUT_BITS-1:0] sine_tab_y;
	sine_table tab(.x(sine_tab_x), .y(sine_tab_y));

	// Invert output if needed
	wire invert_y_msb    = phase[`SINE_IN_BITS + 1];
	wire invert_y_bottom = invert_y_msb ^ use_sharp;

	wire [`SINE_OUT_BITS+1-1:0] y0 = sine_tab_y;
	//assign y = y0 ^ (invert_y ? '1 : '0);
	assign y = y0 ^ {invert_y_msb, {`SINE_OUT_BITS{invert_y_bottom}}};
	assign cosappr = ~sine_tab_x[`SINE_IN_BITS-1 -: COSAPPR_BITS];
endmodule


module graphics_renderer #(parameter NUM_WAVES=3, NUM_WAVE_INDS=3, RESTART_COUNTER_BITS=2) (
		input wire clk, reset,
		input wire restart,
		input wire [RESTART_COUNTER_BITS-1:0] restart_counter,

		input wire on_screen,  // when low, the scan line hasn't started yet
		input wire [`DZ_BITS-1:0] screen_pos,

		input wire initialize_phase,
		input wire [`PHASE_BITS-1:0] phase_init,
		input wire [`Z_BITS-1:0] z_init,
		input wire signed [`DZ_BITS-1:0] dz_init,
		input wire [`T_BITS-1:0] min_t,
		input wire flip_min_t_compare,

		output wire [$clog2(NUM_WAVE_INDS)-1:0] curr_wave_index,
		input wire signed [`DPHASE_BITS-1:0] dphase, // dphase = dphases[curr_wave_index]

		input wire [$clog2(NUM_WAVE_INDS)-1:0] sine_shifter_shr,
		output wire signed [`SINE_OUT_BITS+1+2**$clog2(NUM_WAVE_INDS)-1-1:0] sine_shifter_out,

		input wire force_forward,
		input wire [`NSTEP_BITS-1:0] nstep_max,
		input wire sharp_sine, semi_sharp_sine,
		input wire [$clog2(NUM_WAVE_INDS)-1:0] last_wave_index,
		input wire block_zg_acc,

		output wire black, occlusion,
		output wire [`COLOR_BITS-1:0] output_color
	);

	localparam NSTEP_BITS = `NSTEP_BITS;
	localparam NSTEP_PERIOD_BITS = `NSTEP_PERIOD_BITS;

	localparam WAVE_INDEX_BITS = $clog2(NUM_WAVE_INDS);

	localparam DPHASE_BITS = `DPHASE_BITS;
	localparam PHASE_BITS = `PHASE_BITS;

	localparam ZG_BITS = `ZG_BITS;
	localparam COSAPPR_BITS = `COSAPPR_BITS;

	localparam DZ_BITS = `DZ_BITS;
	localparam Z_BITS = `Z_BITS;
	localparam Z_ZG_BITS = `Z_ZG_BITS;
	localparam T_BITS = `T_BITS;


	localparam STEP_SHIFT_BITS = 2**NSTEP_BITS-1;


	genvar i;


	// Step size control
	// =================
	wire write_zg;

	reg [NSTEP_BITS-1:0] nstep_reg, nstep_zg;
	reg [NSTEP_PERIOD_BITS-1:0] nstep_counter;

	//reg vis;
	//wire next_vis;
	//wire [NSTEP_BITS-1:0] nstep = (nstep_reg == '0) ? 0 : nstep_reg - vis;
	wire [NSTEP_BITS-1:0] nstep = nstep_reg;

	wire [NSTEP_PERIOD_BITS+1-1:0] nstep_counter_dec = nstep_counter - 1;
	wire nstep_counter_wraps = nstep_counter_dec[NSTEP_PERIOD_BITS];
	//wire [NSTEP_PERIOD_BITS-1:0] next_nstep_counter = nstep_counter_dec;
	wire [NSTEP_PERIOD_BITS-1:0] next_nstep_counter = {nstep_counter_dec[NSTEP_PERIOD_BITS-1] && !nstep_counter_wraps, nstep_counter_dec[NSTEP_PERIOD_BITS-1-1:0]};

	wire [NSTEP_BITS-1:0] next_nstep = nstep_reg + (write_zg && nstep_counter_wraps && (nstep_reg != nstep_max));
	//wire [NSTEP_BITS-1:0] next_nstep = nstep_reg + (write_zg && nstep_counter_wraps && (nstep_reg != '1) && !force_forward);
	//wire [NSTEP_BITS-1:0] next_nstep = nstep_reg + (force_forward ? (screen_pos[6:0]=='0) : (write_zg && nstep_counter_wraps && (nstep_reg != '1)));
	//wire [NSTEP_BITS-1:0] next_nstep = nstep_reg + (write_zg && nstep_counter_wraps && (nstep_reg != 2));

	always_ff @(posedge clk) begin
		if (restart) begin
			nstep_reg <= 0;
			nstep_counter <= '1;
		end else begin
			if (write_zg) begin
				nstep_counter <= next_nstep_counter;
				nstep_zg <= nstep;
			end
			nstep_reg <= next_nstep; // changes only when write_zg is high
		end
	end


	// Phases
	// ======
	localparam DPHASE_SHIFTED_BITS = DPHASE_BITS + STEP_SHIFT_BITS;

	// Doesn't move past wave_index = NUM_WAVES - 1 until zg_replace is true; waits inactive instead.
	// The same applies to zg evaluation.
	// zg_replace only has an effect when last_wave is true.
	wire zg_replace;

	reg [WAVE_INDEX_BITS-1:0] wave_index;
	(* mem2reg *) reg [PHASE_BITS-1:0] phases[NUM_WAVES];

	//assign curr_wave_index = wave_index;
	assign curr_wave_index = restart ? restart_counter[WAVE_INDEX_BITS-1:0] : wave_index;

	//wire last_wave = (wave_index == NUM_WAVES - 1);
	wire last_wave = wave_index == last_wave_index;
	wire [WAVE_INDEX_BITS-1:0] next_wave_index = restart || (last_wave && zg_replace) ? 0 : wave_index + !last_wave;
	always_ff @(posedge clk) begin
		//if (reset) vis <= 1;
		//else if (last_wave && zg_valid) vis <= next_vis;
		wave_index <= next_wave_index;
	end


	reg [ZG_BITS-1:0] zg_acc, zg; // TODO: clock gate, shared n-latches


	// Choose curr_phase
`ifndef USE_FM
	wire [PHASE_BITS-1:0] curr_phase = phases[curr_wave_index];
`else
	reg [PHASE_BITS-1:0] curr_phase; // not a register
	always_comb begin
		case (curr_wave_index)
			0: curr_phase = phases[0];
			1: curr_phase = phases[1];
			2: curr_phase = phases[2];
			3: curr_phase = {zg_acc, {(PHASE_BITS-ZG_BITS+1){1'b0}}};
			default: curr_phase = 'X;
		endcase
	end
`endif

	wire signed [DPHASE_SHIFTED_BITS-1:0] dphase_ext = dphase;
	wire signed [DPHASE_SHIFTED_BITS-1:0] dphase_shifted = dphase_ext << nstep;
	wire signed [PHASE_BITS-1:0] dphase_shifted_ext = dphase_shifted;
//	wire [PHASE_BITS-1:0] next_phase = curr_phase + dphase;
	wire [PHASE_BITS-1:0] next_phase = curr_phase + dphase_shifted_ext;

	generate
		for (i = 0; i < NUM_WAVES; i++) begin
			always_ff @(posedge clk) begin
				if (restart) begin
					if (initialize_phase && restart_counter[WAVE_INDEX_BITS-1:0] == i) phases[i] <= phase_init;
				end else begin
					// can use wave_index instead of curr_wave_index since restart is low here
					if (i == wave_index && (i != NUM_WAVES - 1 || zg_replace)) phases[i] <= next_phase; // TODO: clock gate
				end
			end
		end
	endgenerate


	// zg evaluation
	// =============
	wire zg_done;

	localparam MAP_IN_BITS  = `SINE_IN_BITS  + 2;
	localparam MAP_OUT_BITS = `SINE_OUT_BITS + 1;
	localparam MAP_OUTPUT_SHIFT_BITS = 2;

	localparam COSAPPR_TERM_BITS = COSAPPR_BITS - 2;

	reg zg_valid;
	reg [COSAPPR_BITS-1:0] cosappr_acc, cosappr; // TODO: clock gate, shared n-latches

	wire signed [MAP_OUT_BITS-1:0] sine_tab_y;
	wire [COSAPPR_TERM_BITS-1:0] delta_cosappr;
	full_sine_table #(.COSAPPR_BITS(COSAPPR_TERM_BITS)) tab(.phase(curr_phase[PHASE_BITS-1 -: MAP_IN_BITS]), .sharp(sharp_sine), .semi_sharp(semi_sharp_sine), .y(sine_tab_y), .cosappr(delta_cosappr));


//	wire signed [ZG_BITS-1:0] delta_zg = sine_tab_y >>> wave_index;

	// TODO: remove shift count mux if unused
	// can use wave_index instead of curr_wave_index since restart is low when we do:
`ifdef USE_FM
	wire lfm = (wave_index == 3) && !force_forward;
	wire [WAVE_INDEX_BITS-1:0] sine_shifter_shr_count = restart ? sine_shifter_shr : (wave_index == 3 ? (force_forward ? 0 : 1): wave_index);
	wire [ZG_BITS-1:0] zg_acc_base = lfm ? -(1 << (ZG_BITS-2)) : (1 << (ZG_BITS-1));
`else
	wire [WAVE_INDEX_BITS-1:0] sine_shifter_shr_count = restart ? sine_shifter_shr : wave_index;
	wire [ZG_BITS-1:0] zg_acc_base = 1 << (ZG_BITS-1);
`endif
	//wire [WAVE_INDEX_BITS-1:0] sine_shifter_shr_count = restart ? sine_shifter_shr : wave_index + 1;
	//wire [WAVE_INDEX_BITS-1:0] sine_shifter_shr_count = restart ? sine_shifter_shr : 1;

	localparam EXTRA_SINE_SHIFTER_BITS = 2**WAVE_INDEX_BITS - 1;
	localparam SINE_SHIFTER_BITS = MAP_OUT_BITS + EXTRA_SINE_SHIFTER_BITS;

	wire signed [SINE_SHIFTER_BITS-1:0] sine_shifter_in = {sine_tab_y, {EXTRA_SINE_SHIFTER_BITS{1'b0}}};
	//wire signed [SINE_SHIFTER_BITS-1:0] sine_shifter_out = sine_shifter_in >>> sine_shifter_shr_count;
	assign sine_shifter_out = sine_shifter_in >>> sine_shifter_shr_count;
	wire signed [ZG_BITS-1:0] delta_zg = sine_shifter_out >>> (EXTRA_SINE_SHIFTER_BITS + `ZG_SHR);



	wire zg_acc_mask, write_zg_acc;
	assign zg_acc_mask = (wave_index != 0); // can use wave_index instead of curr_wave_index since don't care about behavior during restart phase
	assign write_zg_acc = !last_wave;
	assign write_zg = last_wave && zg_replace;

	//wire [ZG_BITS-1:0] zg_sum = (zg_acc_mask ? zg_acc : zg_acc_base) + delta_zg;
	wire [ZG_BITS-1:0] zg_sum = ((zg_acc_mask && !block_zg_acc) ? zg_acc : zg_acc_base) + delta_zg;
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

	assign zg_replace = !zg_valid || zg_done;


	// Z stepping
	// ==========
	reg [Z_BITS-1:0] z;
//	reg signed [`DZ_BITS-1:0] dz;

	// TODO: share n-latches
	reg [DZ_BITS-1:0] dz;
	reg [T_BITS-1:0] neg_t;

	wire [T_BITS-1:0] nonneg_t = -neg_t; // Just for debug


`ifdef USE_EXTRA_Z_RANGE
	wire z_below_g = z[Z_BITS-1];
	wire z_in_zg_range = z[Z_BITS-1-1:Z_ZG_BITS] == '1;
`else
	wire z_below_g = 0;
	wire z_in_zg_range = 1;
`endif


	//wire gr_hit = z_in_zg_range && (z[Z_ZG_BITS-1 -: ZG_BITS] >= zg);
	wire gr_hit = (z_in_zg_range && z_in_zg_range && (z[Z_ZG_BITS-1 -: ZG_BITS] >= zg)) || z_below_g;
/*
	localparam EXTRA_Z_BITS = Z_BITS - Z_ZG_BITS;
	wire gr_hit = z[Z_BITS-1 -: (ZG_BITS + EXTRA_Z_BITS)] >= {{EXTRA_Z_BITS{1'b1}}, zg};
*/
	assign zg_done = zg_valid && (!gr_hit || force_forward);

	localparam DZ_SHIFTED_BITS = DZ_BITS + STEP_SHIFT_BITS;
	wire [DZ_SHIFTED_BITS-1:0] dz_ext = dz;
	wire [DZ_SHIFTED_BITS-1:0] dz_shifted = dz_ext << nstep_zg;

	//wire [DZ_SHIFTED_BITS-1:0] neg_t_ext = {{(DZ_SHIFTED_BITS-T_BITS){1'b1}}, neg_t}; // causes wrong behavior
	wire [Z_BITS-1:0] neg_t_ext = {{(Z_BITS-T_BITS){1'b1}}, neg_t};

//	wire [Z_BITS-1:0] z_plus = z + (gr_hit ? neg_t_ext : dz);
	wire [Z_BITS-1:0] z_plus = z + (gr_hit ? neg_t_ext : dz_shifted);
//	wire [`MAX_DZ_T_BITS-1:0] dz_or_t_dec = (gr_hit ? dz : neg_t) - 1;
	wire [`MAX_DZ_T_BITS-1:0] dz_or_t_dec = (gr_hit ? {1'b0, dz} : neg_t) - (1 << (gr_hit ? 0 : nstep_zg));

	wire screen_behind = !on_screen || (screen_pos > dz);
	wire screen_ahead = !screen_behind && !(screen_pos == dz);
	wire step_up = zg_valid && gr_hit && !screen_behind;
	wire step_forward = zg_valid && !gr_hit;

	always_ff @(posedge clk) begin
		if (restart) begin
			z <= z_init;
			dz <= dz_init;
			neg_t <= '0;
		end else if (zg_valid) begin
			/*
			if (gr_hit) begin
				//z  <= z - t;
				z  <= z + neg_t_ext;
				dz <= dz - 1;
			end else begin
				z <= z + dz;
				//t <= t + 1;
				neg_t <= neg_t - 1;
			end
			*/
			/*
			z <= z_plus;
			if (gr_hit) dz    <= dz_or_t_dec;
			else            neg_t <= dz_or_t_dec;
			*/
			if (step_up || step_forward) z     <= z_plus;
			if (step_up)                 dz    <= dz_or_t_dec;
			if (step_forward)            neg_t <= dz_or_t_dec;
		end
	end


	// Output
	//wire [`COLOR_BITS-1:0] color = zg;
	//wire [`COLOR_BITS-1:0] color = neg_t;

	wire [`COLOR_CHANNEL_BITS-1:0] r, g, b;
	//assign g = ~zg[ZG_BITS-1 -: `COLOR_CHANNEL_BITS];
	wire [`COLOR_CHANNEL_BITS-1:0] g0 = cosappr[COSAPPR_BITS-1 -: `COLOR_CHANNEL_BITS];
	//assign g = force_forward ? ~z[Z_BITS-1 -: `COLOR_CHANNEL_BITS] : g0;
	assign g = g0;

	wire [`COLOR_CHANNEL_BITS+1-1:0] l = ~zg[ZG_BITS-1 -: `COLOR_CHANNEL_BITS+1];
	wire bright = l[`COLOR_CHANNEL_BITS];
	//assign r = bright ? l : '0;
	wire [`COLOR_CHANNEL_BITS-1:0] r0 = bright ? l[`COLOR_CHANNEL_BITS-1:0] : '0;
	//assign r = (r0 < g || force_forward) ? r0 : g;
	assign r = (r0 < g0) ? r0 : g0;
	//assign b = bright ? '1 : l;

	wire [`COLOR_CHANNEL_BITS-1:0] b0 = ~zg[ZG_BITS-1 -: `COLOR_CHANNEL_BITS];
	//assign b = force_forward ? z[Z_BITS-1 -: `COLOR_CHANNEL_BITS] : b0;
	assign b = b0;

	wire [`COLOR_BITS-1:0] color = {r, g, b};

	//assign black = !(zg_valid && !screen_ahead && on_screen && (neg_t >= ~max_t)) && !force_forward;
	//assign black = !(zg_valid && !screen_ahead && on_screen && (flip_min_t_compare ^(neg_t <= ~min_t))) && !force_forward;
	assign black = !(zg_valid && !screen_ahead && on_screen && (flip_min_t_compare ^(neg_t <= ~min_t))) && !force_forward && on_screen;
	//assign output_color = black ? '0 : color;

	//assign next_vis = screen_ahead && !force_forward;

	assign output_color = color;
	assign occlusion = (nstep_reg == 0) && !force_forward;
endmodule : graphics_renderer

module graphics_top #(
		parameter X_BITS=10, Y_BITS=9, X_SUB_BITS=1, NUM_WAVES=3, NUM_WAVE_INDS=`NUM_WAVE_INDS, X_FINE_PERIOD=100, X_COARSE_BITS=3, Y_STEPS=525, Y_SAT_BITS=9,
		FRAME_COUNTER_BITS=14, LOG2_GRAPHICS_PERIOD=12, FULL_FPS=1
	) (
		input wire clk, reset,

		input wire audio_out,
		input wire raise_drum,

		input wire advance_frame, pause,

		output wire show_audio,
		output wire [`PLAYER_CONTROL_BITS-1:0] player_control,

		output wire [3*`FINAL_COLOR_CHANNEL_BITS-1:0] rgb_out,
		output wire hsync, vsync,
//		output reg hsync, vsync,
		output wire new_frame,

		output wire enable,
		output wire [$clog2(X_FINE_PERIOD)-1:0] x_fine,
		output wire [X_COARSE_BITS-1:0] x_coarse,
		output wire [Y_SAT_BITS-1:0] y_sat, y_wrap,
		output wire [FRAME_COUNTER_BITS-1:0] raw_frame_counter
	);

	// RESTART_STEP_BITS + RESTART_COUNTER_BITS must be <= 5
	localparam RESTART_STEP_BITS = 1;
	localparam RESTART_COUNTER_BITS = 3;

	localparam WAVE_INDEX_BITS = $clog2(NUM_WAVE_INDS);
	localparam MAP_OUT_BITS = `SINE_OUT_BITS + 1;
	localparam EXTRA_SINE_SHIFTER_BITS = 2**WAVE_INDEX_BITS - 1;
	localparam SINE_SHIFTER_BITS = MAP_OUT_BITS + EXTRA_SINE_SHIFTER_BITS;


	genvar i;


	// Raster scan
	// ===========

	reg [FRAME_COUNTER_BITS-1:0] r_frame_counter;
	assign raw_frame_counter = r_frame_counter;
	wire [FRAME_COUNTER_BITS+1-FULL_FPS-1:0] frame_counter = FULL_FPS ? r_frame_counter : {r_frame_counter, 1'b0};

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
/*
	// TODO: Why do I need to delay these by one cycle? Is it the correct thing to do?
	always @(posedge clk) begin
		vsync <= vsync0;
		hsync <= hsync0;
	end
*/

	/*
	wire [5:0] rgb = {x[3:2], x[1:0], y[1:0]};
	assign rgb_out = scan_flags[`I_ACTIVE] ? rgb : '0;
	*/

/*
	wire [`T_BITS-1:0] min_t = '0;
	//wire [`T_BITS-1:0] min_t = ~(frame_counter >> 1) & 255;
	//wire [`T_BITS-1:0] min_t = frame_counter[9] ? 0 : ~(frame_counter >> 1) & 255;
	//wire [`T_BITS-1:0] min_t = frame_counter[9] ? 0 : (~frame_counter & 511);

`ifdef USE_FM
	wire fm_on = 0; //frame_counter[8];
`else
	wire fm_on = 0;
`endif

	wire sharp_sine = 0;
	//wire sharp_sine = !restart && frame_counter[8];
	//wire sharp_sine = !restart;
	//wire sharp_sine = 1;

	wire force_forward = 0;
	//wire force_forward = 1;
	//wire force_forward = frame_counter[8];


	//wire [`NSTEP_BITS-1:0] nstep_max = frame_counter[LOG2_GRAPHICS_PERIOD-4 -: 2];
	//wire [`NSTEP_BITS-1:0] nstep_max = '1;
	wire [`NSTEP_BITS-1:0] nstep_max = force_forward ? frame_counter[LOG2_GRAPHICS_PERIOD-4 -: 2] : '1;
	//wire [`NSTEP_BITS-1:0] nstep_max = 0;

	wire add_y_to_phase = dphase_we;
	//wire add_y_to_phase = !dphase_we;
	//wire add_y_to_phase = 1;

	assign show_audio = 0;
	//assign show_audio = frame_counter[6];
	wire jumps_on = 0;
*/

	wire restart;
	wire [RESTART_COUNTER_BITS-1:0] restart_counter;

	// Control
	// =======
	localparam LOG2_SECTION_FRAMES = 11;
	localparam SECTION_BITS = FRAME_COUNTER_BITS+1 - LOG2_SECTION_FRAMES;

`ifdef FPGA
	wire [SECTION_BITS-1:0] section = frame_counter >> LOG2_SECTION_FRAMES; // four chord loops per section
	//wire [SECTION_BITS-1:0] section = 4;
	//wire [SECTION_BITS-1:0] section = frame_counter[LOG2_SECTION_FRAMES] ? 4 : 3;
	//wire [SECTION_BITS-1:0] section = frame_counter[LOG2_SECTION_FRAMES] ? 5 : 4;
`else
	wire [SECTION_BITS-1:0] section = frame_counter >> LOG2_SECTION_FRAMES; // four chord loops per section
`endif

	wire [1:0] subsect = frame_counter >> (LOG2_SECTION_FRAMES - 2); // one chord loop per subsect
	wire [1:0] subsubsect = frame_counter >> (LOG2_SECTION_FRAMES - 4); // one chord per subsubsect
	wire [1:0] sub3sect = frame_counter >> (LOG2_SECTION_FRAMES - 6);

	//wire fade_in, force_forward, fm_on, sharp_sine, show_audio, jumps_on;
	//wire fade_in=0, force_forward=0, fm_on=0, sharp_sine=0, show_audio=0, jumps_on=0;
	//wire fade_in=0, force_forward=1, fm_on=0, sharp_sine=0, show_audio=0, jumps_on=1;

	// not registers
	reg fade_in, logo_on, logo_fade_in, logo_fade_invert, force_forward, fm_on, sharp_sine, semi_sharp_sine, sharp_sine_init, visual_audio;
	reg jumps_on, flip_min_t_compare, graphics_on;
	reg [1:0] add_y;
	reg [`PLAYER_CONTROL_BITS-1:0] p_control;
	always_comb begin
		fade_in = 0; logo_on = 1; logo_fade_in = 0; logo_fade_invert = 0; force_forward = 0; fm_on = 0; sharp_sine = 0; semi_sharp_sine = 1; sharp_sine_init = 0;
		visual_audio = 0; jumps_on = 0; flip_min_t_compare = 0; graphics_on = 1;
		add_y = 2'b10;
		p_control[`PC_CHORDS_ON] = 1;
		p_control[`PC_DETUNE_LEAD] = 0;
		p_control[`PC_SIMPLE_BASS] = 0;
		p_control[`PC_MODULATE] = 0;
		p_control[`PC_RESOLUTION] = 0;
		p_control[`PC_PRERESOLUTION] = 0;
		p_control[`PC_SILENCE] = 0;
		p_control[`PC_RAISE_BASS] = 0;
		p_control[`PC_SQUARE_LEAD] = 0;
		case (section)
			0: begin
				fade_in = (subsect == 0);
				logo_on = (subsect[1] == 1);
				logo_fade_in = (subsect == 1);
				p_control[`PC_SIMPLE_BASS] = !logo_on;
			end
			1: begin
				force_forward = 1;
				case (subsect)
					0: begin end
					1: begin add_y = 2'b01; end
					2: begin add_y = 2'b11; fm_on = 1; end
					3: begin add_y = 2'b11; sharp_sine = 1; sharp_sine_init = 1; end
				endcase
			end
			2: begin
				p_control[`PC_CHORDS_ON] = 0;
				p_control[`PC_DETUNE_LEAD] = 1;
				sharp_sine = (subsect[1] == 0);
				//semi_sharp_sine = sharp_sine;
				fm_on = (subsect[1] == 1);
			end
			3: begin
				//visual_audio = (sub3sect[1] == 1);
				//visual_audio = 1;
				p_control[`PC_PRERESOLUTION] = (subsect == '1) && (subsubsect == '1);
				p_control[`PC_MODULATE] = p_control[`PC_PRERESOLUTION];
				visual_audio = !subsect[1] || sub3sect[1] || p_control[`PC_PRERESOLUTION];
				case ({subsect[0], subsubsect[1]})
					0: force_forward = 1;
					1: sharp_sine = 1;
					2: fm_on = 1;
				endcase
			end
			4: begin
				p_control[`PC_MODULATE] = 1;
				//p_control[`PC_RAISE_BASS] = subsect[1];
				p_control[`PC_SQUARE_LEAD] = subsect[1] ^ (sub3sect == '1);
				p_control[`PC_PRERESOLUTION] = (subsect == '1) && (subsubsect == '1);
				jumps_on = 1;
			end
			5: begin
				p_control[`PC_MODULATE] = 1;
				//p_control[`PC_RESOLUTION] = (subsect == '0) && (subsubsect == '0);
				//p_control[`PC_SILENCE] = !p_control[`PC_RESOLUTION];
				//p_control[`PC_RESOLUTION] = (subsect == '0);
				p_control[`PC_RESOLUTION] = 1;
				//p_control[`PC_SILENCE] = !p_control[`PC_RESOLUTION];
				p_control[`PC_SILENCE] = (subsect != '0);
				flip_min_t_compare = 1;
				fade_in = (subsect == 0);
				graphics_on = (subsect == 0);
				logo_fade_invert = 1;
				logo_fade_in = (subsect == 1);
				logo_on = (subsect == 0);
			end
			//default : ;
		endcase
	end
	assign show_audio = visual_audio;
	assign player_control = p_control;


	//wire [`T_BITS-1:0] min_t = fade_in ? ~(frame_counter >> 1) & 255 : '0;
	wire [`T_BITS-1:0] min_t = fade_in ? ~frame_counter & 511 : '0;
	//wire [`NSTEP_BITS-1:0] nstep_max = 0;
	//wire [`NSTEP_BITS-1:0] nstep_max = force_forward ? subsubsect : '1;

	wire [`NSTEP_BITS-1:0] nstep_max_g = '1;
	//wire [`NSTEP_BITS-1:0] nstep_max_g = (section == 4) ? ~subsubsect : (section[2] ? 0 : '1);
	wire [`NSTEP_BITS-1:0] nstep_max = force_forward ? subsubsect : nstep_max_g;



	// Graphics
	// ========

	wire dphase_we = restart && restart_counter[RESTART_COUNTER_BITS-1:WAVE_INDEX_BITS] == 0;

	//wire add_y_to_phase = dphase_we;
	//wire add_y_to_phase = add_y[dphase_we];
	wire add_y_to_phase = restart ? add_y[dphase_we] : 1;
	//wire add_y_to_phase = !dphase_we;
	//wire add_y_to_phase = 1;


	wire [WAVE_INDEX_BITS-1:0] sine_shifter_shr = ~restart_counter[WAVE_INDEX_BITS-1:0];
	//wire [WAVE_INDEX_BITS-1:0] sine_shifter_shr = 2-restart_counter;

/*
	wire signed [`DPHASE_BITS-1:0] dphases[NUM_WAVES];

	assign dphases[0] = {{(`DPHASE_BITS-8){~y[8]}}, y[7:0]};
//	assign dphases[0] = ~y >> 2;
	//assign dphases[0] = ~y;
	//assign dphases[0] = {2'd0, y} - 240;
	assign dphases[1] = 511;
	assign dphases[2] = y;
*/

	wire signed [SINE_SHIFTER_BITS-1:0] sine_shifter_out;
	wire [`DPHASE_BITS-1:0] next_dphase = sine_shifter_out[SINE_SHIFTER_BITS-1 -: `DPHASE_BITS];

	wire [NUM_WAVES-1:0] dphase_dest_mask;
	generate
		for (i = 0; i < NUM_WAVES; i++) begin
			assign dphase_dest_mask[i] = dphase_we && restart_counter[WAVE_INDEX_BITS-1:0] == i+(RESTART_STEP_BITS==0);
		end
	endgenerate

`ifdef USE_DPHASE_LATCHES
	wire signed [`DPHASE_BITS-1:0] dphases[NUM_WAVES];
	wire [`DPHASE_BITS*NUM_WAVES-1:0] all_dphases;
	np_latch_registers #( .NUM_REGS(NUM_WAVES), .DATA_BITS(`DPHASE_BITS) ) dphase_latches(
		.clk(clk), .reset(reset),
		.we(dphase_dest_mask), .wdata(next_dphase),
		.all_data(all_dphases)
	);

	generate
		for (i = 0; i < NUM_WAVES; i++) begin
			assign dphases[i] = all_dphases[(i+1)*`DPHASE_BITS-1 -: `DPHASE_BITS];
		end
	endgenerate

`else
	(* mem2reg *) reg signed [`DPHASE_BITS-1:0] dphases[NUM_WAVES];

	generate
		for (i = 0; i < NUM_WAVES; i++) begin
			always_ff @(posedge clk) begin
				//if (dphase_we && restart_counter[WAVE_INDEX_BITS-1:0] == i+1) dphases[i] <= next_dphase;
				//if (dphase_we && restart_counter[WAVE_INDEX_BITS-1:0] == i) dphases[i] <= next_dphase;
				//if (dphase_we && restart_counter[WAVE_INDEX_BITS-1:0] == i+(RESTART_STEP_BITS==0)) dphases[i] <= next_dphase;
				if (dphase_dest_mask[i]) dphases[i] <= next_dphase;
			end
		end
	endgenerate
`endif



	assign restart = (x_coarse == '0 && x_fine[$clog2(X_FINE_PERIOD)-1:RESTART_COUNTER_BITS+RESTART_STEP_BITS] == '0);
	assign restart_counter = x_fine[RESTART_COUNTER_BITS+RESTART_STEP_BITS-1:RESTART_STEP_BITS];

	wire on_screen = h_active && !x[9];
	wire [`DZ_BITS-1:0] screen_pos = ~x[`DZ_BITS-1:0];

	wire [WAVE_INDEX_BITS-1:0] curr_wave_index;
	wire signed [`DPHASE_BITS-1:0] dphase = dphases[curr_wave_index];

	wire initialize_phase = 1;


	//wire quick_logo_move = x[4];
	wire quick_logo_move = x[3];
	wire [2:0] phase_shl_active = quick_logo_move ? 2 : 1;

	wire bounce = 0;
	//wire bounce = jumps_on && raise_drum;
	//wire bounce = jumps_on && (raise_drum || subsect[1]);

	wire bounce_en = bounce && (restart_counter == 6);

`ifndef USE_GRAPHICS_JUMPS
	wire [2:0] phase_shl = restart ? restart_counter[2:0] : phase_shl_active;
	//wire [1:0] phase_shl = active ? x[6:5] : (restart_counter[1:0] + restart_counter[2]);
	//wire [2:0] phase_shl = active ? x[7:5] : restart_counter[2:0];

`else
	localparam PHASE_SPEEDUP = 3;
	localparam LOG2_PHASE_PERIOD = LOG2_GRAPHICS_PERIOD - PHASE_SPEEDUP;
	localparam PHASE_SWITCH_SPEEDUP = 3;

	//wire [1:0] pt_fc = jumps_on ? frame_counter[LOG2_PHASE_PERIOD-PHASE_SWITCH_SPEEDUP+1 -: 1] : '0;
	wire [1:0] pt_fc = frame_counter[LOG2_PHASE_PERIOD-PHASE_SWITCH_SPEEDUP+2 -: 2];

	//wire [2:0] phase_init_shl0 = restart_counter[1:0] ^ pt_fc;
	//wire [2:0] phase_init_shl0 = restart_counter == 6 ? 5-PHASE_SPEEDUP : (restart_counter[1:0] ^ pt_fc);
	wire [2:0] phase_init_shl0 = bounce_en ? 5-PHASE_SPEEDUP : (restart_counter[1:0] ^ pt_fc);

	wire [2:0] phase_init_shl = jumps_on ? phase_init_shl0 + PHASE_SPEEDUP : restart_counter;
	wire [2:0] phase_shl = restart ? ({2'b0, restart_counter[2]} ? phase_init_shl : {1'b0, restart_counter[1:0]}) : phase_shl_active;
`endif

	// Calculate phase_init0
	// ---------------------
	wire [`PHASE_BITS-1:0] pt1 = {frame_counter, {(`PHASE_BITS-LOG2_GRAPHICS_PERIOD){1'b0}}};
	//wire [`PHASE_BITS+1-1:0] phase_init0 = pt1 << phase_shl;
	//wire [`PHASE_BITS+1-1:0] pt2 = pt1 << phase_shl[0];
	wire [`PHASE_BITS-1:0] pt2 = phase_shl[0] ? ~pt1 << 1 : pt1; // reverse sign for every other shift count
	wire [`PHASE_BITS-1:0] phase_mask = bounce_en ? {(`PHASE_BITS-2){1'b1}} : '1;
	wire [`PHASE_BITS-1:0] phase_init0 = (pt2 << (phase_shl & ~1)) & phase_mask;

	wire phase_90 = dphase_we && restart_counter[0];

	localparam Y_MOVED_BITS = Y_BITS + 2;

	localparam Y_SHL_BITS = `PHASE_BITS-Y_BITS-2;
	wire [`PHASE_BITS-1:0] phase_init = phase_init0 + (add_y_to_phase ? {1'b0, phase_90, y, {(Y_SHL_BITS){1'b0}}} : '0);
	//wire [`PHASE_BITS-1:0] phase_init = phase_init0 + (dphase_we || active ? {y, {(Y_SHL_BITS){1'b0}}} : '0);
	wire [Y_MOVED_BITS-1:0] y_moved = phase_init >> Y_SHL_BITS; 

	//wire [WAVE_INDEX_BITS-1:0] last_wave_index = NUM_WAVES - 1;
	//wire [WAVE_INDEX_BITS-1:0] last_wave_index = NUM_WAVE_INDS - 1;
	wire [WAVE_INDEX_BITS-1:0] last_wave_index = fm_on ? NUM_WAVE_INDS - 1 : NUM_WAVES - 1;

`ifdef USE_FM
	wire block_zg_acc = (curr_wave_index == 3);
`else
	wire block_zg_acc = 0;
`endif


	wire [`Z_BITS-1:0] z_init = '0;
	//wire [`Z_BITS-1:0] z_init = {frame_counter, 7'b0} & {`Z_ZG_BITS{1'b1}};


	wire [`DZ_BITS-1:0] dz_init = (1 << `DZ_BITS) - 1;

	wire [`COLOR_BITS-1:0] color;
	wire black, occlusion;
	graphics_renderer #(.NUM_WAVES(NUM_WAVES), .NUM_WAVE_INDS(NUM_WAVE_INDS), .RESTART_COUNTER_BITS(RESTART_COUNTER_BITS)) pipeline(
		.clk(clk), .reset(reset),
		.restart(restart), .restart_counter(restart_counter),
		.on_screen(on_screen), .screen_pos(screen_pos),
		.initialize_phase(initialize_phase), .phase_init(phase_init),
		.z_init(z_init), .dz_init(dz_init), .min_t(min_t), .flip_min_t_compare(flip_min_t_compare),
		.curr_wave_index(curr_wave_index),
		.dphase(dphase),
		.sine_shifter_shr(sine_shifter_shr), .sine_shifter_out(sine_shifter_out),
		 .sharp_sine(sharp_sine && (!restart || sharp_sine_init)), .semi_sharp_sine(semi_sharp_sine && (!restart || sharp_sine_init)), 
		.force_forward(force_forward), .nstep_max(nstep_max), .last_wave_index(last_wave_index), .block_zg_acc(block_zg_acc),
		.output_color(color), .black(black), .occlusion(occlusion)
	);

	// Logo
	// ====
`ifdef USE_LOGO
	wire [3:0] logo_x = ~x[7:4];
	wire [8:0] y_l = y_wrap;
	//wire [8:0] y_l = y_moved;
	wire [4:0] logo_y = y_l[8:4];

	// Determine logo_part (logo rotation)
	// -----------------------------------
	wire [10:0] logo_t = frame_counter << 2;
	//wire logo_move = (logo_t[10:9] == '1) && !logo_t[6];
	wire logo_move = raise_drum && !logo_t[6];

	reg logo_rot_rev; // not a register
	always_comb begin
		case (logo_t[8:7])
			0: logo_rot_rev = 0;
			1: logo_rot_rev = 1;
			2: logo_rot_rev = logo_x[0];
			3: logo_rot_rev = logo_y[0];
		endcase
	end

	wire [4:0] logo_rot;
	assign logo_rot = logo_move ? (logo_t[4:0] ^ (logo_rot_rev ? 5'h1f : 5'h0)): '0;

	//wire logo_part = x[3:0] > y_l[3:0];
	//wire [4:0] logo_diff = y_l[3:0] - x[3:0];
	wire [4:0] logo_diff = y_l[3:0] - x[3:0] + logo_rot; // TODO: carry save adder?
	wire logo_part = logo_diff[4];


	wire [9:0] logo_addr = {logo_y, logo_x, logo_part};
	wire logo_data;
	logo_table logo(
		.addr(logo_addr), .data(logo_data)
	);
	
	//wire [Y_MOVED_BITS-1:0] ym = y_moved + (quick_logo_move ? -2**Y_BITS : 2**Y_BITS);
	wire [Y_MOVED_BITS-1:0] ym = y_moved + (quick_logo_move ? -5*2**(Y_BITS-2) : 2**Y_BITS);
	wire logo_mask = ym[Y_BITS+1] ^ logo_fade_invert;

	wire force_sat0 = logo_data && x[8] && (logo_on || (logo_fade_in && logo_mask));
	`ifdef USE_OCCLUSION
	wire force_sat = (force_sat0 && !occlusion);
	//wire force_sat = (force_sat0 && !occlusion) || audio_out;
	`else
	wire force_sat = force_sat0;
//	wire force_sat = force_sat0 || audio_out;
	`endif
`else
	wire force_sat = 0;
`endif


	//wire force_black = y[Y_BITS-1] != y_moved[Y_BITS-1];
	wire force_black = 0;
	wire black2 = black || !graphics_on;


	wire audio_mask = audio_out;
	wire [`FINAL_COLOR_CHANNEL_BITS-1:0] audio_channel[3];
	//wire [1:0] audio_tint = (x_coarse[X_COARSE_BITS-1 -: 2] - 1) >> 1;
	wire [2:0] xc = x_coarse[X_COARSE_BITS-1 -: 3];
	//wire [1:0] audio_tint = ~((xc >> 1) - 1);
	wire [1:0] audio_tint = ~(xc >> 1);
	assign audio_channel[2] = audio_mask ? 3 : 0;
	assign audio_channel[1] = audio_mask ? audio_tint : 0;
	assign audio_channel[0] = audio_channel[1];


	// Dithering
	// =========
	//wire [`COLOR_DITHER_BITS-1:0] dither = y;
	//wire [`COLOR_DITHER_BITS-1:0] dither = {y[0], y[1]};
	//wire [`COLOR_DITHER_BITS-1:0] dither = {y[0], x[0]};
	//wire [`COLOR_DITHER_BITS-1:0] dither = {y[0], x[0]} + raw_frame_counter[1:0];
	wire [`COLOR_DITHER_BITS-1:0] dither = {y[0]^x[1], x[0]};
	generate
		for (i = 0; i < 3; i++) begin
			wire black3 = black2 || (!force_forward && !on_screen && (i != 2 || !sharp_sine));

			wire [`COLOR_CHANNEL_BITS+1-1:0] dither_sum = color[(i+1)*`COLOR_CHANNEL_BITS-1 -: `COLOR_CHANNEL_BITS] + dither;
			//wire [`FINAL_COLOR_CHANNEL_BITS-1:0] channel = (force_sat | dither_sum[`COLOR_CHANNEL_BITS]) ? '1 : dither_sum[`COLOR_CHANNEL_BITS-1 -: `FINAL_COLOR_CHANNEL_BITS];

			wire [`FINAL_COLOR_CHANNEL_BITS-1:0] channel0 = show_audio ? audio_channel[i] : dither_sum[`COLOR_CHANNEL_BITS-1 -: `FINAL_COLOR_CHANNEL_BITS];
			wire force_sat2 = force_sat | (dither_sum[`COLOR_CHANNEL_BITS] && !show_audio);
			wire [`FINAL_COLOR_CHANNEL_BITS-1:0] channel = force_sat2 ? '1 : channel0;

			//wire channel = color[(i+1)*`COLOR_CHANNEL_BITS-1 -: `FINAL_COLOR_CHANNEL_BITS];
			assign rgb_out[(i+1)*`FINAL_COLOR_CHANNEL_BITS-1 -: `FINAL_COLOR_CHANNEL_BITS] = (active && !force_black && (show_audio || !black3 || force_sat)) ? channel : '0;
		end
	endgenerate


	// TODO: sync to pixel
	//assign rgb_out = color;

	wire [FRAME_COUNTER_BITS-1:0] r_frame_counter_inc = r_frame_counter + ((new_frame && !pause)|| advance_frame);
	wire [FRAME_COUNTER_BITS+1-FULL_FPS-1:0] frame_counter_inc = FULL_FPS ? r_frame_counter_inc : {r_frame_counter_inc, 1'b0};
	wire [SECTION_BITS-1:0] section_inc = frame_counter_inc >> LOG2_SECTION_FRAMES; // four chord loops per section
	wire restart_frame_counter = section_inc[SECTION_BITS-1:1] == (6 >> 1);

	always @(posedge clk) begin
		if ((reset || restart_frame_counter) && !advance_frame) r_frame_counter <= 0;
		//if (reset) r_frame_counter <= 3 << (LOG2_SECTION_FRAMES + FULL_FPS - 1);
		else r_frame_counter <= r_frame_counter_inc;
	end
endmodule
