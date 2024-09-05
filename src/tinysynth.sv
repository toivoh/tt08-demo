/*
 * Copyright (c) 2024 Toivo Henningsson
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none
`include "synth_common.vh"
`include "common_generated.vh"


`define LOWER1

`define NEW_BASS
`define NEW_LEAD


module mantissa_table(
		input wire [3:0] note,
		output wire [6:0] mantissa
	);

	reg [6:0] mantissas[16];
	initial begin
		mantissas[ 0] = 246;
		mantissas[ 1] = 232;
		mantissas[ 2] = 219;
		mantissas[ 3] = 207;
		mantissas[ 4] = 195;
		mantissas[ 5] = 184;
		mantissas[ 6] = 174;
		mantissas[ 7] = 164;
		mantissas[ 8] = 155;
		mantissas[ 9] = 146;
		mantissas[10] = 138;
		mantissas[11] = 130;
	end

	assign mantissa = mantissas[note];
endmodule


module ALU #(parameter A_BITS=12, NUM_REGS=`NUM_ALU_REGS, OCT_BITS=3, OSHIFT=5) (
		input wire clk, reset,
		input wire enable,

		input wire [`A_SRC_BITS-1:0] a_src,
		input wire [`S_SRC_BITS-1:0] s_src,
		input wire [`SHIFT_COUNT_BITS-1:0] shift_count,

`ifdef USE_SHARED_MANTISSA_TABLE
		input wire [3:0] note,
		input wire [3:0] note_bass,
		input wire [3:0] note_lead,
`else
		input wire [A_BITS-1-1:0] mantissa,
		input wire [A_BITS-1-1:0] mantissa_bass,
		input wire [A_BITS-1-1:0] mantissa_lead,
`endif
		input wire [OCT_BITS-1:0] oct,
		input wire [OCT_BITS-1:0] oct_bass,
		input wire [OCT_BITS-1:0] oct_lead,
		input wire [A_BITS-1-1:0] mantissa_drums,
		input wire [OCT_BITS-1:0] oct_drums,

		input wire invert_s, add_carry,
		input wire update_acc, update_carry,
		input wire [NUM_REGS-1:0] dest_mask,
		input wire update_oct_en,

		input wire [2**OCT_BITS-1-1:0] oct_counter,
		input wire [A_BITS+2**`SHIFT_COUNT_BITS-1-1:0] detune_counter,

		input wire [`PLAYER_CONTROL_BITS-1:0] control,

		output wire signed [A_BITS-1:0] out//,
		//output wire [2*A_BITS-1:0] sample_counter
	);

	genvar i;

	reg [A_BITS-1:0] acc; // accumulator register
	reg carry;
	reg oct_en;

	// TODO:
	// - use latches
	// - don't store all bits for all registers
`ifdef USE_LATCHES
	wire [A_BITS-1:0] registers[NUM_REGS];
`else
	(* mem2reg *) reg [A_BITS-1:0] registers[NUM_REGS];
`endif

	// Mantissa table
	// --------------
`ifdef USE_SHARED_MANTISSA_TABLE
	reg [3:0] curr_note0; // not a register
	always_comb begin
		case (s_src & 3)
			`S_MANTISSA & 3: curr_note0 = note;
			`S_MANTISSA_BASS & 3: curr_note0 = note_bass;
			`S_MANTISSA_LEAD & 3: curr_note0 = note_lead;
			default: curr_note0 = 'X;
		endcase
		//end
	end
	wire [3:0] curr_note = curr_note0 + control[`PC_MODULATE];

	wire [6:0] mantissa0;
	mantissa_table mtable(.note(curr_note), .mantissa(mantissa0));
	wire [A_BITS-1-1:0] mantissa = {mantissa0, {(A_BITS-1-7){1'b0}}};

	wire [A_BITS-1-1:0] mantissa_bass = mantissa;
	wire [A_BITS-1-1:0] mantissa_lead = mantissa;
`endif

	// Form acc_rev
	// ------------
	// Ignore LSB of acc, which is the delayed bit
	wire [A_BITS-1:0] acc_rev;
	generate
		for (i = 0; i < A_BITS-1; i++) assign acc_rev[i] = acc[A_BITS-1-i];
	endgenerate
	assign acc_rev[A_BITS-1] = 0;

	// Find a_val
	// ----------
	//localparam OSHIFT_CHORD = OSHIFT + `CHORD_EXTRA_OSHIFT;

	// not registers
	reg [A_BITS-1:0] a_val;
	reg [`A_SRC_BITS-1:0] a_src2;
	always_comb begin
		a_val = 'X;
		a_src2 = a_src;
		//if (a_src == `A_ABS && acc[A_BITS-1] == 0) a_src2 = `A_A;
		case (a_src2)
			`A_ZERO:     a_val = 0;
			`A_ONE:      a_val = 1;
			`A_99:       a_val = 96; // 96 should be enough
			`A_A:        a_val = acc;
			//`A_ABS:      a_val = {1'b0, ~acc[A_BITS-2:0]}; //~acc; // modified to A_A if acc is positive
			`A_TRI:      a_val = {acc[A_BITS-1] ? ~acc[A_BITS-2:0] : acc[A_BITS-2:0], 1'b0} ^ (1 << (A_BITS-1));
			//`A_OSHIFTED: a_val = {{OSHIFT{acc[A_BITS-1]}}, acc[A_BITS-1:OSHIFT]};
			`A_OSHIFTED: a_val = {{OSHIFT{1'b0}}, ~acc[A_BITS-1], acc[A_BITS-1-1:OSHIFT]};
			//`A_OSHIFTED_CHORD: a_val = {{OSHIFT_CHORD{acc[A_BITS-1]}}, acc[A_BITS-1:OSHIFT_CHORD]};
			`A_SHR1:     a_val = {acc[A_BITS-1], acc[A_BITS-1:1]};
			`A_REV:      a_val = acc_rev;
			default:     a_val = 'X;
		endcase
	end

	// Find s_val
	// ----------
	localparam EXTRA_SHIFTER_BITS = 2**`SHIFT_COUNT_BITS - 1;
	localparam SHIFTER_BITS = A_BITS + EXTRA_SHIFTER_BITS;

	//wire [2*A_BITS-1:0] oct_counter12 = {registers[`S_OCT_COUNTER2], registers[`S_OCT_COUNTER]};
	//wire [SHIFTER_BITS+`MIN_OC_SHIFT-1:0] oct_counter12 = {registers[`S_OCT_COUNTER2], registers[`S_OCT_COUNTER]};
	//wire [SHIFTER_BITS-1:0] shifter_in = (s_src == `S_B) ? {registers[`S_B], {EXTRA_SHIFTER_BITS{1'b0}}} : oct_counter12[SHIFTER_BITS+`MIN_OC_SHIFT-1 -: SHIFTER_BITS];
	wire [SHIFTER_BITS-1:0] shifter_in = (s_src == `S_B) ? {registers[`S_B], {EXTRA_SHIFTER_BITS{1'b0}}} : detune_counter;
	wire [SHIFTER_BITS-1:0] shifter_out0 = shifter_in << shift_count;
	wire [A_BITS-1:0] shifter_out = shifter_out0[SHIFTER_BITS-1 -: A_BITS];

	reg [A_BITS-1:0] s_val; // not a register
	always_comb begin
		s_val = 'X;
		/*
		if (s_src < `S_NONREG_BASE) begin
			s_val = registers[s_src[$clog2(NUM_REGS)-1:0]];
		end else begin*/
		case (s_src)
			//`S_B: s_val = registers[`S_B] << shift_count;
			`S_B, `S_OC_SHIFTED: s_val = shifter_out;
			`S_PHASE: s_val = registers[`S_PHASE];
			`S_PHASE_DRUMS: s_val = registers[`S_PHASE_DRUMS];
			`S_PHASE_BASS: s_val = registers[`S_PHASE_BASS];
			`S_PHASE_LEAD: s_val = registers[`S_PHASE_LEAD];
			`S_OCT_COUNTER: s_val = oct_counter;
			//`S_OCT_COUNTER: s_val = registers[`S_OCT_COUNTER];
			//`S_OCT_COUNTER2: s_val = registers[`S_OCT_COUNTER2];
			`S_OUTPUT_ACC: s_val = registers[`S_OUTPUT_ACC];
			//`S_OUTPUT: s_val = registers[`S_OUTPUT]; // never needs to be read

			`S_ZERO: s_val = 0;
			`S_A_SIGN: s_val = {acc[A_BITS-1], {(A_BITS-1){1'b0}}};
			`S_MANTISSA: s_val = {1'b0, mantissa};
			`S_MANTISSA_DRUMS: s_val = {1'b0, mantissa_drums};
			`S_MANTISSA_BASS: s_val = {1'b0, mantissa_bass};
			`S_MANTISSA_LEAD: s_val = {1'b0, mantissa_lead};
			`S_PHASEINC: s_val = oct_en ? (acc[0] || !carry ? 1 : 2) : 0;
			default: s_val = 'X;
		endcase
		//end
	end

	// Calulate ALU result
	// -------------------
	wire carry_in = add_carry ? carry : invert_s;
	// TODO: is general invert needed?
	wire [A_BITS-1:0] s_val2 = invert_s ? ~s_val : s_val;
	wire [A_BITS+1-1:0] sum = a_val + s_val2 + carry_in;

	// Update state
	// ============
	always_ff @(posedge clk) begin
		// TODO: clock gated FFs
		if (reset) begin
			acc <= 0;
			carry <= 0;
		end else begin
			if (update_acc && enable) acc <= sum[A_BITS-1:0];
			if (update_carry && enable) carry <= sum[A_BITS];
		end
	end

	// Update registers
	// ----------------
	wire [A_BITS-1:0] reg_masks[NUM_REGS];
	generate
		for (i = 0; i < NUM_REGS; i++) begin
`ifdef USE_ALU_REG_PRUNING
			//wire [A_BITS-1:0] mask = (i == `S_OUTPUT_ACC || i == `S_OUTPUT) ? {(`PROG_ADDR_BITS){1'b1}} : '1;
			reg [A_BITS-1:0] mask; // not a register
			always_comb begin
				mask = '1;
				if (i == `S_OUTPUT_ACC || i == `S_OUTPUT) mask = {(`PROG_ADDR_BITS){1'b1}};
				//if (i == `S_PHASE_LEAD) mask = {(A_BITS-2){1'b1}}; // the lead is raised two octaves ==> two unused MSBs
				if (i == `S_PHASE_LEAD || i == `S_PHASE_BASS) mask = {(A_BITS-3){1'b1}}; // raised 3 octaves ==> 3 unused MSBs
				//if (i == `S_PHASE_LEAD || i == `S_PHASE_BASS || i == `S_PHASE_DRUMS) mask = {(A_BITS-3){1'b1}}; // raised 3 octaves ==> 3 unused MSBs
			end
`else
			wire [A_BITS-1:0] mask = '1;
`endif
			assign reg_masks[i] = mask;
		end
	endgenerate

`ifdef USE_LATCHES
	/*
module np_latch_registers #( parameter NUM_REGS=2, DATA_BITS=8 ) (
		input wire clk, reset,

		input wire [NUM_REGS-1:0] we,
		input wire [DATA_BITS-1:0] wdata,
		//output wire [DATA_BITS-1:0] rdata
		output wire [NUM_REGS*DATA_BITS-1:0] all_data
	);
	*/
	wire [NUM_REGS*A_BITS-1:0] all_regs;
`ifdef USE_ALU_REG_PRUNING
	np_latch_registers #( .NUM_REGS(NUM_REGS), .DATA_BITS(A_BITS), .USE_ALU_REG_PRUNING(1) ) alu_regs(
`else
	np_latch_registers #( .NUM_REGS(NUM_REGS), .DATA_BITS(A_BITS) ) alu_regs(
`endif
		.clk(clk), .reset(reset),
		.we(reset ? '1 : (enable ? dest_mask : '0)), .wdata(reset ? '0 : acc),
		.all_data(all_regs)
	);
	generate
		for (i = 0; i < NUM_REGS; i++) begin
			//wire [A_BITS-1:0] mask = '1;
			//wire [A_BITS-1:0] mask = (i == `S_OUTPUT_ACC || i == `S_OUTPUT) ? {(`PROG_ADDR_BITS){1'b1}}  : '1;
			assign registers[i] = reg_masks[i] & all_regs[(i+1)*A_BITS-1 -: A_BITS];
		end
	endgenerate
`else
	generate
		for (i = 0; i < NUM_REGS; i++) begin
			always_ff @(posedge clk) begin
				if (dest_mask[i] && enable) registers[i] <= acc & reg_masks[i];
			end
		end
	endgenerate
`endif

	// Update oct_en
	// -------------
	//wire [A_BITS+1-1:0] oct_enables = {a_val & ~s_val, 1'b1};
	wire [2**OCT_BITS-1:0] oct_enables = {a_val & ~s_val, 1'b1} & ((1 << (2**OCT_BITS-1)) - 1);
	reg [OCT_BITS-1:0] curr_oct; // not a register
	always_comb begin
		case (shift_count[1:0])
			0: curr_oct = oct;
			1: curr_oct = oct_drums;
			2: curr_oct = oct_bass;
			3: curr_oct = oct_lead;
			default: curr_oct = 'X;
		endcase
	end

	wire next_oct_en = oct_enables[curr_oct];
	always_ff @(posedge clk) begin
		if (update_oct_en && enable) oct_en <= next_oct_en;
	end

	// Outputs
	// =======
	assign out = registers[`S_OUTPUT];
	//assign sample_counter = {registers[`S_OCT_COUNTER2], registers[`S_OCT_COUNTER]};
endmodule : ALU


module alu_synth #(parameter A_BITS=12, NUM_REGS=`NUM_ALU_REGS, OCT_BITS=3, OSHIFT=5) (
		input wire clk, reset,
		input wire enable,

		input wire [`PROG_ADDR_BITS-1:0] program_addr,
		input wire [2**OCT_BITS-1-1:0] oct_counter,
		input wire [A_BITS+2**`SHIFT_COUNT_BITS-1-1:0] detune_counter,

`ifdef USE_SHARED_MANTISSA_TABLE
		input wire [3:0] note,
		input wire [3:0] note_bass,
		input wire [3:0] note_lead,
`else
		input wire [A_BITS-1-1:0] mantissa,
		input wire [A_BITS-1-1:0] mantissa_bass,
		input wire [A_BITS-1-1:0] mantissa_lead,
`endif
		input wire [OCT_BITS-1:0] oct,
		input wire [OCT_BITS-1:0] oct_bass,
		input wire [OCT_BITS-1:0] oct_lead,
		input wire [A_BITS-1-1:0] mantissa_drums,
		input wire [OCT_BITS-1:0] oct_drums,

		output wire [2:0] factor_src,
		input wire [`SHIFT_COUNT_BITS-1:0] factor_shift,
		input wire factor_sub,
		output wire [`SHIFT_COUNT_BITS-1:0] shift_count, // for testing, otherwise just used internally

		output wire [`TAG_BITS-1:0] inst_tag,

		input wire [`PLAYER_CONTROL_BITS-1:0] control,

		output wire signed [A_BITS-1:0] out
		//output wire [2*A_BITS-1:0] sample_counter,
		//output wire [`PROG_ADDR_BITS-1:0] program_addr
	);

	/*
	reg [`PROG_ADDR_BITS-1:0] prog_addr;
	always_ff @(posedge clk) begin
		if (reset) begin
			prog_addr <= 0;
		end else begin
			if (prog_addr == `PROG_ADDR_SIZE-1) prog_addr <= 0;
			else prog_addr <= prog_addr + 1;
		end
	end
	*/
	wire [`PROG_ADDR_BITS-1:0] prog_addr = program_addr;

	wire [`A_SRC_BITS-1:0] a_src;
	wire [`S_SRC_BITS-1:0] s_src;
	//wire [`SHIFT_COUNT_BITS-1:0] shift_count;
	wire [NUM_REGS-1:0] dest_mask;

	wire [`MOP_FLAG_BITS-1:0] flags;
	wire invert_s, add_carry, update_acc, update_carry, update_oct_en;
	assign {invert_s, add_carry, update_acc, update_carry, update_oct_en} = reset ? '0 : flags;

	wire factor_override = (factor_src[2:1] != '1);

	alu_program prog(.addr(prog_addr), .a_src(a_src), .shift(shift_count), .s_src(s_src), .dmask(dest_mask), .flags(flags), .fasrc(factor_src), .tag(inst_tag));

	ALU #(.A_BITS(A_BITS), .OCT_BITS(OCT_BITS), .OSHIFT(OSHIFT)) alu (
		.clk(clk), .reset(reset), .enable(enable),
		.a_src(a_src), .s_src(s_src),
		.shift_count(factor_override ? factor_shift : shift_count),
		.dest_mask(reset ? '0 : dest_mask),
		.invert_s(factor_override ? factor_sub : invert_s), .add_carry(add_carry), .update_acc(update_acc), .update_carry(update_carry), .update_oct_en(update_oct_en),
`ifdef USE_SHARED_MANTISSA_TABLE
		.note(note[3:0]), .note_bass(note_bass[3:0]), .note_lead(note_lead[3:0]),
`else
		.mantissa(mantissa), .mantissa_bass(mantissa_bass), .mantissa_lead(mantissa_lead),
`endif
		.oct(oct), .oct_bass(oct_bass), .oct_lead(oct_lead),
		.mantissa_drums(mantissa_drums), .oct_drums(oct_drums),
		.oct_counter(oct_counter), .detune_counter(detune_counter),
		.control(control),
		.out(out)
	);

	//assign program_addr = prog_addr;
endmodule : alu_synth


module player #(parameter A_BITS=12, OCT_BITS=3, OSHIFT=5, TRACK_LOG2_WAIT=19, SAMPLE_COUNTER_BITS=23) (
		input wire clk, reset,
		input wire enable,

		input wire [`PROG_ADDR_BITS-1:0] program_addr,
		input wire [SAMPLE_COUNTER_BITS-1:0] sample_counter,
		input wire [2**OCT_BITS-1-1:0] oct_counter,
		input wire [A_BITS+2**`SHIFT_COUNT_BITS-1-1:0] detune_counter,

		input wire visual,
		input wire [`PLAYER_CONTROL_BITS-1:0] control,
		input wire [`EXT_CONTROL_BITS-1:0] ext_control,

		output wire raise_drum,
		output wire signed [A_BITS-1:0] out
		//output wire [`PROG_ADDR_BITS-1:0] program_addr
	);

	localparam TRACK_POS_BITS = 2;
	localparam LOG2_SILENCE_CHORD = 3;

`ifdef NEW_BASS
	localparam BASS_TRACK_POS_BITS = 4;
	localparam BASS_TRACK_LOG2_WAIT = TRACK_LOG2_WAIT - BASS_TRACK_POS_BITS;
`else
	localparam BASS_TRACK_POS_BITS = 3;
	localparam BASS_TRACK_LOG2_WAIT = TRACK_LOG2_WAIT - BASS_TRACK_POS_BITS - 1;
`endif

	localparam LEAD_TRACK_POS_BITS = 5;
	localparam LEAD_TRACK_LOG2_WAIT = TRACK_LOG2_WAIT - LEAD_TRACK_POS_BITS + 2;

	localparam DRUM_LOG2_PERIOD = TRACK_LOG2_WAIT - 2;
	localparam DRUM_LOG2_OCTS = 2;
	localparam DRUM_FREQ_BITS = A_BITS-1 + DRUM_LOG2_OCTS;


`ifdef LOWER1
	localparam DELTA_NOTE = -1;
//	localparam DELTA_NOTE2 = 16+12-1;
`define DELTA_NOTE2 (control[`PC_MODULATE] ? 16-1 : 16+12-1)
`else
	localparam DELTA_NOTE = 0;
	localparam DELTA_NOTE2 = 0;
`endif


	wire lead_on, lead_on0;

	wire silence_chord;
	wire second_loop;
	wire [TRACK_POS_BITS-1:0] track_pos, track_pos0;
	reg [7:0] note; // not a register
	always_comb begin
		/*
		case (track_pos)
			0: note = 8'h17; // G
			1: note = 8'h18; // Ab
			2: note = 8'h1a; // Bb
			3: note = 8'h00; // C+1
			default: note = 'X;
		endcase
		*/
		case (track_pos)
			0: note = 8'h10 + `DELTA_NOTE2; // C1
			1: note = 8'h27 + DELTA_NOTE; // G0
			2: note = 8'h25 + DELTA_NOTE; // F0
			//3: note = 8'h21 + DELTA_NOTE; // Db0
			//3: note = 8'h25 + DELTA_NOTE; // F0
			3: note = control[`PC_CHORDS_ON] ? 8'h21 + DELTA_NOTE : 8'h28 + DELTA_NOTE; // Db0 / Ab0
			default: note = 'X;
		endcase
		if (silence_chord || control[`PC_SILENCE]) note = 8'hfX; // highest octave number = silence
		//note = 8'h10;
		//note = 8'hfX;
	end
	assign raise_drum = (track_pos0 == 3) && second_loop;
	//assign raise_drum = ((track_pos0 == 3) && second_loop) || (control[`PC_MODULATE] && lead_on0);


	wire [BASS_TRACK_POS_BITS-1:0] bass_track_pos;
	reg [7:0] bass_note, bass_note1, bass_note2; // not a register
	always_comb begin
		//case (visual ? 0 : track_pos)
		case (track_pos)
			0: begin bass_note1 = 8'h30 + `DELTA_NOTE2; bass_note2 = 8'h37 + DELTA_NOTE; end // C1, G1
			1: begin bass_note1 = 8'h32 + DELTA_NOTE; bass_note2 = 8'h37 + DELTA_NOTE; end // D1, G1
			2: begin bass_note1 = 8'h30 + `DELTA_NOTE2; bass_note2 = 8'h35 + DELTA_NOTE; end // C1, F1
//			3: begin bass_note1 = 8'h30 + `DELTA_NOTE2; bass_note2 = 8'h35 + DELTA_NOTE; end // C1, F1
			3: begin bass_note1 = 8'h35 + DELTA_NOTE; bass_note2 = 8'h38 + DELTA_NOTE; end // F1, Ab1 TODO: Detune third of chord to match!
			default: begin bass_note1 = 'X; bass_note2 = 'X; end
		endcase
`ifdef NEW_BASS
		if (control[`PC_SIMPLE_BASS]) begin
			case (bass_track_pos)
				0, 2, 4, 8, 12, 14: bass_note = bass_note1;
				1, 6, 10, 13: bass_note = bass_note2;
				default: bass_note = 8'hfX;
			endcase
		end else if (track_pos0 != 3) begin
			case (bass_track_pos)
				0, 2, 4, 5, 8, 12, 13: bass_note = bass_note1;
				1, 6, 10, 14: bass_note = bass_note2;
				default: bass_note = 8'hfX;
			endcase
		end else begin
			case (bass_track_pos)
				//0, 4, 8, 12, 14: bass_note = bass_note1;
				//2, 6, 10, 13, 15: bass_note = bass_note2;
				//0, 4, 8, 10, 12, 13: bass_note = bass_note1;
				//2, 6, 9, 11, 14: bass_note = bass_note2;
				0, 4, 8, 9, 12: bass_note = bass_note1;
				2, 6, 10, 14: bass_note = bass_note2;
				default: bass_note = 8'hfX;
			endcase
		end
`else 
		case (bass_track_pos)
			0, 4, 5: bass_note = bass_note1;
			2, 6: bass_note = bass_note2;
			default: bass_note = 8'hfX;
		endcase
`endif
		//if (control[`PC_SILENCE]) bass_note = 8'hfX; // highest octave number = silence
		//bass_note = 8'hfX;
	end

	wire [LEAD_TRACK_POS_BITS-1:0] lead_track_pos;
	wire lead_track_pos_sub;
	// not registers
	reg [7:0] lead_note;
	reg lead_echo;

`ifndef NEW_LEAD
	always_comb begin
		lead_echo = 0;
		// arpeggios
		case (control[`PC_RESOLUTION] ? 5'h0 : lead_track_pos)
			'h00, 'h03: lead_note = 8'h10 + `DELTA_NOTE2; // C
			'h01, 'h04, 'h06: lead_note = 8'h14 + DELTA_NOTE; // E
			'h02, 'h05, 'h07: lead_note = 8'h17 + DELTA_NOTE; // G

			'h08, 'h0b: lead_note = 8'h2b + DELTA_NOTE; // B
			'h09, 'h0c, 'h0e: lead_note = 8'h12 + DELTA_NOTE; // D
			'h0a, 'h0d, 'h0f: lead_note = 8'h17 + DELTA_NOTE; // G

			'h10, 'h13: lead_note = 8'h10 + `DELTA_NOTE2; // C
			'h11, 'h14, 'h16: lead_note = 8'h15 + DELTA_NOTE; // F
			'h12, 'h15, 'h17: lead_note = 8'h19 + DELTA_NOTE; // A

/*
			'h18, 'h1b: lead_note = 8'h10 + `DELTA_NOTE2; // C
			'h19, 'h1c: lead_note = 8'h15 + DELTA_NOTE; // F
			'h1a, 'h1d: lead_note = 8'h18 + DELTA_NOTE; // Ab

			'h1f: lead_note = 8'h15 + DELTA_NOTE; // F
			'h1e: lead_note = 8'h10 + `DELTA_NOTE2; // C
			//'h1f: lead_note = 8'h18 + DELTA_NOTE; // Ab
			//'h1e: lead_note = 8'h00 + `DELTA_NOTE2; // C+
*/
			'h18, 'h1b: lead_note = control[`PC_PRERESOLUTION] ? 8'h29 + DELTA_NOTE : 8'h10 + `DELTA_NOTE2; // A / C
			//'h19, 'h1c: lead_note = control[`PC_PRERESOLUTION] ? 8'h12 + DELTA_NOTE : 8'h15 + DELTA_NOTE; // D / F
			'h19:       lead_note = control[`PC_PRERESOLUTION] ? 8'h12 + DELTA_NOTE : 8'h15 + DELTA_NOTE; // D / F
			'h1c:       lead_note = control[`PC_PRERESOLUTION] ? 8'h10 + `DELTA_NOTE2 : 8'h15 + DELTA_NOTE; // C / F
			'h1a, 'h1d: lead_note = control[`PC_PRERESOLUTION] ? 8'h17 + DELTA_NOTE : 8'h18 + DELTA_NOTE; // G / Ab

			'h1e: lead_note = control[`PC_PRERESOLUTION] ? 8'h12 + DELTA_NOTE : 8'h15 + DELTA_NOTE; // D / F
			'h1f: lead_note = control[`PC_PRERESOLUTION] ? (lead_track_pos_sub ? 8'hfX : 8'h29 + DELTA_NOTE) : 8'h10 + `DELTA_NOTE2; // A / C

			default: lead_note = 8'hfX;
		endcase
		if ((!lead_on && !control[`PC_RESOLUTION]) || control[`PC_SILENCE] || (control[`PC_RESOLUTION] && track_pos0[1])) lead_note = 8'hfX;
		lead_echo = control[`PC_RESOLUTION] ? track_pos0 : (lead_track_pos[2:1] == '1) && (lead_track_pos[4:3] != '1);
		//lead_note = 8'hfX;
	end
`else
	localparam LEAD_NOTE_ID_BITS = 3; // TODO: size?

`ifdef USE_LEAD_EMB
	wire lead_emb = control[`PC_MODULATE] && !control[`PC_PRERESOLUTION];
`else
	wire lead_emb = 0;
`endif

	wire track_pos_not_3 = track_pos != 3;
	reg [LEAD_NOTE_ID_BITS-1:0] lead_note_id; // not a register
	reg [7:0] lead_C; // not a register
	always_comb begin
		lead_echo = 0;
		lead_C = 8'h10 + `DELTA_NOTE2; // C
		// TODO: pre-resolution!
		case (control[`PC_RESOLUTION] ? 3'h0 : lead_track_pos[2:0])
			0, 3: lead_note_id = 0; // C
			1, 4: lead_note_id = 1; // E
			2, 5: lead_note_id = 2; // G
`ifndef USE_LEAD_EMB
			6: lead_note_id = 1; // E
			7: lead_note_id = (lead_track_pos[4:3] != '1) ? 2 : 0; // G / C
`else
			//6: lead_note_id = !lead_emb ? 1 : (!lead_track_pos_sub ? 1 : 3); // E / (D F)
			//6: lead_note_id = !lead_emb ? 1 : (!lead_track_pos_sub ? (lead_track_pos[4:3] != 0) : 3); // E / (D F)
			//6: lead_note_id = 1; // E
			6: lead_note_id = !lead_emb ? (track_pos_not_3 ? 1 : 0) : 3; // (E / C) / F
			//7: lead_note_id = !lead_emb ? (track_pos_not_3 ? 2 : 1) : 2; // (G / E) / G
			//7: lead_note_id = !lead_emb ? (track_pos[0] == 0 ? 2 : 1) : 2; // (G / E) / G
			7: lead_note_id = !lead_emb ? (track_pos[0] == 0 || control[`PC_PRERESOLUTION] ? 2 : 1) : 2; // (G / E) / G
`endif
			default: lead_note_id = 'X;
		endcase

`ifdef USE_LEAD_EMB
		if (lead_emb && lead_track_pos[2:1] == '1) begin
			if (lead_track_pos[0] == 0 && lead_track_pos_sub == 0) case (track_pos)
				0: lead_note_id = 0;
				1: lead_note_id = 1;
				2: lead_note_id = 1;
				3: lead_note_id = 'X; //1;
			endcase
			//if (lead_track_pos[0] == 1 && track_pos == 3) lead_note_id = 3;
			if (track_pos == 3) lead_note_id = !lead_track_pos[0] ? 1 : 3;
		end
`endif


		case (track_pos)
			0: case (lead_note_id)
				0: lead_note = lead_C; // C
				1: lead_note = 8'h14 + DELTA_NOTE; // E
				2: lead_note = 8'h17 + DELTA_NOTE; // G
`ifdef USE_LEAD_EMB
				3: lead_note = 8'h15 + DELTA_NOTE; // F
`endif
				default: lead_note = 'X;
			endcase
			1: case (lead_note_id)
				0: lead_note = !control[`PC_PRERESOLUTION] ? 8'h2b + DELTA_NOTE : 8'h29 + DELTA_NOTE; // B / A
				1: lead_note = !(control[`PC_PRERESOLUTION] && lead_track_pos[2:1] == 2'b10) ? 8'h12 + DELTA_NOTE : lead_C; // D / C
				2: lead_note = 8'h17 + DELTA_NOTE; // G
`ifdef USE_LEAD_EMB
				//3: lead_note = 8'h15 + DELTA_NOTE; // F
				3: lead_note = 8'h17 + DELTA_NOTE; // G
`endif
				default: lead_note = 'X;
			endcase
			2: case (lead_note_id)
				0: lead_note = lead_C; // C
				1: lead_note = 8'h15 + DELTA_NOTE; // F
				2: lead_note = 8'h19 + DELTA_NOTE; // A
`ifdef USE_LEAD_EMB
				3: lead_note = 8'h17 + DELTA_NOTE; // G
				//3: lead_note = 8'h15 + DELTA_NOTE; // F
`endif
				default: lead_note = 'X;
			endcase
			3: case (lead_note_id)
				0: lead_note = lead_C; // C
				1: lead_note = 8'h15 + DELTA_NOTE; // F
				2: lead_note = 8'h18 + DELTA_NOTE; // Ab
`ifdef USE_LEAD_EMB
				3: lead_note = 8'h13 + DELTA_NOTE; // Eb
`endif
				default: lead_note = 'X;
			endcase
			default: lead_note = 'X;
		endcase
		if ((!lead_on && !control[`PC_RESOLUTION]) || control[`PC_SILENCE] || (control[`PC_RESOLUTION] && track_pos0[1])) lead_note = 8'hfX;
		//lead_echo = control[`PC_RESOLUTION] ? track_pos0[0] : (lead_track_pos[2:1] == '1) && (lead_track_pos[4:3] != '1) && !lead_emb;
		lead_echo = control[`PC_RESOLUTION] ? track_pos0[0] : (lead_track_pos[2:1] == '1) && (lead_track_pos[3] == 0) && !lead_emb;
		//lead_note = 8'hfX;
	end
`endif

	wire [2:0] factor_src;
	// Not registers
	reg [`SHIFT_COUNT_BITS-1:0] factor_shift;
	reg factor_sub;
	always_comb begin
		factor_sub = 0;
		factor_shift = 'X;
		if (control[`PC_CHORDS_ON]) begin
			case (track_pos)
				0: case (factor_src[2:1]) // 8  10 12
					0: begin factor_shift = 2; end
					1: begin factor_shift = factor_src[0] ? 1 : 3; end
					2: begin factor_shift = factor_src[0] ? 2 : 3; end
				endcase
				1: case (factor_src[2:1]) // 16 10 12
					0: begin factor_shift = 3; end // 16
	//				1: begin factor_shift = factor_src[0] ? 1 : 3; end // 10
					1: begin factor_shift = factor_src[0] ? 0 : 3; end // 9
					2: begin factor_shift = factor_src[0] ? 2 : 3; end // 12
				endcase
				2: case (factor_src[2:1]) // 16 20 12
					0: begin factor_shift = 3; end
					1: begin factor_shift = factor_src[0] ? 2 : 4; end
					2: begin factor_shift = factor_src[0] ? 2 : 3; end
				endcase
				3: case (factor_src[2:1]) // 15 20 24
					0: begin factor_shift = factor_src[0] ? 0 : 4; factor_sub = factor_src[0]; end
					//0: begin factor_shift = 3; end
					1: begin factor_shift = factor_src[0] ? 2 : 4; end
					2: begin factor_shift = factor_src[0] ? 3 : 4; end
				endcase
			endcase
		end else begin
			//factor_shift = 2; // 8
			factor_shift = 1; // 4
		end
	end


`ifndef USE_SHARED_MANTISSA_TABLE
	wire [6:0] mantissa0;
	mantissa_table mtable(.note(note[3:0]), .mantissa(mantissa0));
	wire [A_BITS-1-1:0] mantissa = {mantissa0, {(A_BITS-1-7){1'b0}}};

	// TODO: share mantissa table?
	wire [6:0] mantissa_bass0;
	mantissa_table mtable_bass(.note(bass_note[3:0]), .mantissa(mantissa_bass0));
	wire [A_BITS-1-1:0] mantissa_bass = {mantissa_bass0, {(A_BITS-1-7){1'b0}}};
	//wire [OCT_BITS-1:0] oct_bass = 1;
	//wire [A_BITS-1-1:0] mantissa_bass = 0;
	//wire [OCT_BITS-1:0] oct_bass = 0;

	// TODO: share mantissa table?
	wire [6:0] mantissa_lead0;
	mantissa_table mtable_lead(.note(lead_note[3:0]), .mantissa(mantissa_lead0));
	wire [A_BITS-1-1:0] mantissa_lead = {mantissa_lead0, {(A_BITS-1-7){1'b0}}};
`endif
	wire [OCT_BITS-1:0] oct = note[OCT_BITS+4-1:4];
	//wire [OCT_BITS-1:0] oct_bass = bass_note[OCT_BITS+4-1:4];
	//wire [OCT_BITS-1:0] oct_bass = bass_note[OCT_BITS+4-1:4] - (visual && bass_note[OCT_BITS+4-1:4] != '1);
	//wire [OCT_BITS-1:0] oct_bass = bass_note[OCT_BITS+4-1:4] - (visual && bass_note[OCT_BITS+4-1:4] != '1 && !ext_control[`EC_KEEP_BASS_LOW]);
	wire [OCT_BITS-1:0] oct_bass = (visual && ext_control[`EC_VIS_BASS_OFF]) ? '1 :
		(bass_note[OCT_BITS+4-1:4] - (bass_note[OCT_BITS+4-1:4] != '1 && ((visual && !ext_control[`EC_KEEP_BASS_LOW]) || control[`PC_RAISE_BASS])));
	wire [OCT_BITS-1:0] oct_lead = lead_note[OCT_BITS+4-1:4];


	wire [DRUM_FREQ_BITS-1:0] drum_freq;
	wire [A_BITS-1-1:0] mantissa_drums;
	wire [OCT_BITS-1:0] oct_drums0, oct_drums;
	assign {oct_drums0, mantissa_drums} = drum_freq;
	//assign oct_drums = oct_drums0;
	//assign oct_drums = ((!visual || oct_drums0 == 0) && !(control[`PC_SILENCE] || control[`PC_RESOLUTION])) ? oct_drums0 : '1;
	//assign oct_drums = ((!visual || oct_drums0[OCT_BITS-1:1] == 0) && !(control[`PC_SILENCE] || control[`PC_RESOLUTION])) ? oct_drums0 : '1;
	assign oct_drums = ((!visual || (oct_drums0[OCT_BITS-1:1] == 0 && !ext_control[`EC_VIS_DRUMS_OFF])) && !(control[`PC_SILENCE] || control[`PC_RESOLUTION])) ? oct_drums0 : '1;
	//assign oct_drums = (!visual || oct_drums0 == 0) ? (oct_drums0 + (raise_drum ? 2 : 3)) : '1;
	//assign oct_drums = '1;

	wire [`TAG_BITS-1:0] inst_tag;

	//wire inst_enable = 1;
	wire inst_enable = (inst_tag == 0) || (inst_tag == `TAG_RAISE_DRUM && raise_drum)
		|| (inst_tag == `TAG_DETUNE_LEAD && control[`PC_DETUNE_LEAD]) || (inst_tag == `TAG_CHORD_MORE && control[`PC_CHORDS_ON])
		|| (inst_tag == `TAG_LEAD_ECHO && lead_echo) || (inst_tag == `TAG_REDUCE_BASS && visual)
		|| (inst_tag == `TAG_INVERT_OUT && sample_counter[0]) || (inst_tag == `TAG_SQUARE_LEAD && control[`PC_SQUARE_LEAD]);


	//wire [2*A_BITS-1:0] sample_counter;
	alu_synth #(.A_BITS(A_BITS), .OSHIFT(OSHIFT), .OCT_BITS(OCT_BITS)) synth (
		.clk(clk), .reset(reset), .enable(enable && inst_enable),
		.program_addr(program_addr), .oct_counter(oct_counter), .detune_counter(detune_counter),
`ifdef USE_SHARED_MANTISSA_TABLE
		.note(note[3:0]), .note_bass(bass_note[3:0]), .note_lead(lead_note[3:0]),
`else 
		.mantissa(mantissa), .mantissa_bass(mantissa_bass), .mantissa_lead(mantissa_lead), 
`endif
		.oct(oct), .oct_bass(oct_bass), .oct_lead(oct_lead),
		.mantissa_drums(mantissa_drums), .oct_drums(oct_drums),
		.factor_src(factor_src), .factor_shift(factor_shift), .factor_sub(factor_sub),
		.inst_tag(inst_tag),
		.control(control),
		.out(out)//, .sample_counter(sample_counter), .program_addr(program_addr)
	);

	//assign track_pos = sample_counter[TRACK_LOG2_WAIT+TRACK_POS_BITS-1 -: TRACK_POS_BITS];
	assign track_pos0 = sample_counter[TRACK_LOG2_WAIT+TRACK_POS_BITS-1 -: TRACK_POS_BITS];
	assign track_pos = control[`PC_PRERESOLUTION] ? 2'd1 : (control[`PC_RESOLUTION] ? 2'd0 : track_pos0);
	assign bass_track_pos = sample_counter[BASS_TRACK_LOG2_WAIT+BASS_TRACK_POS_BITS-1 -: BASS_TRACK_POS_BITS];
	assign lead_track_pos = sample_counter[LEAD_TRACK_LOG2_WAIT+LEAD_TRACK_POS_BITS-1 -: LEAD_TRACK_POS_BITS];
	assign lead_track_pos_sub = sample_counter[LEAD_TRACK_LOG2_WAIT-1];

	//assign lead_on = !sample_counter[LEAD_TRACK_LOG2_WAIT+LEAD_TRACK_POS_BITS+1];
	assign lead_on0 = sample_counter[LEAD_TRACK_LOG2_WAIT+LEAD_TRACK_POS_BITS+1];
	assign lead_on = lead_on0 || control[`PC_MODULATE];
	assign second_loop = sample_counter[TRACK_LOG2_WAIT+TRACK_POS_BITS];

	assign silence_chord = (sample_counter[TRACK_LOG2_WAIT-1 -: LOG2_SILENCE_CHORD] == '0) && (!control[`PC_RESOLUTION] || (track_pos0 == '0));
	assign drum_freq = sample_counter[DRUM_LOG2_PERIOD-1 -: DRUM_FREQ_BITS];
endmodule
