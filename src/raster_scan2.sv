`default_nettype none

// Phases must be in order
`define XPHASE_ACTIVE 2'd0
`define XPHASE_FP     2'd1
`define XPHASE_SYNC   2'd2
`define XPHASE_BP     2'd3

// Phases must be in order
`define YPHASE_ACTIVE 2'd0
`define YPHASE_FP     2'd1
`define YPHASE_SYNC   2'd2
`define YPHASE_BP     2'd3


module axis_scan_x2 #( parameter FINE_PERIOD = 100, COARSE_BITS = 3 ) (
		input wire clk,
		input wire reset,
		input wire enable,

		output wire [$clog2(FINE_PERIOD)-1:0] x_fine,
		output wire [COARSE_BITS-1:0] x_coarse,
		output wire [COARSE_BITS + $clog2(FINE_PERIOD)-1:0] x,
		output wire carry_fine, carry_coarse,
		output wire active, sync,

		output wire new_line, new_vga_line, active_done
	);

	localparam FINE_BITS = $clog2(FINE_PERIOD);
	localparam BITS = COARSE_BITS + FINE_BITS;

	reg [FINE_BITS-1:0] r_fine;
	reg [COARSE_BITS-1:0] r_coarse;

	reg [1:0] phase;


	assign carry_fine = enable && (r_fine == (FINE_PERIOD - 1));

	wire [FINE_BITS-1:0] next_fine = (reset || carry_fine) ? 0 : (r_fine + enable);
	wire [COARSE_BITS+1-1:0] sum_coarse = r_coarse + carry_fine;


	// not registers
	reg [FINE_BITS-1:0] compare_fine;
	reg [COARSE_BITS-1:0] compare_coarse;
	always_comb begin
		case (phase)
			/*
			`XPHASE_ACTIVE: begin
				compare_fine   = 639 % FINE_PERIOD;
				compare_coarse = 639 / FINE_PERIOD;
			end
			`XPHASE_FP: begin
				compare_fine   = 655 % FINE_PERIOD;
				compare_coarse = 655 / FINE_PERIOD;
			end
			`XPHASE_SYNC: begin
				compare_fine   = 751 % FINE_PERIOD;
				compare_coarse = 751 / FINE_PERIOD;
			end
			`XPHASE_BP: begin
				compare_fine   = 799 % FINE_PERIOD;
				compare_coarse = 799 / FINE_PERIOD;
			end
			*/
			`XPHASE_ACTIVE: begin
				compare_fine   = (128 + 639) % FINE_PERIOD;
				compare_coarse = (128 + 639) / FINE_PERIOD;
			end
			`XPHASE_FP: begin
				compare_fine   = (128 + 655) % FINE_PERIOD;
				compare_coarse = (128 + 655) / FINE_PERIOD;
			end
			`XPHASE_SYNC: begin
				compare_fine   = (751 + 128 - 800) % FINE_PERIOD;
				compare_coarse = (751 + 128 - 800) / FINE_PERIOD;
			end
			`XPHASE_BP: begin
				compare_fine   = (799 + 128 - 800) % FINE_PERIOD;
				compare_coarse = (799 + 128 - 800) / FINE_PERIOD;
			end
			default: begin
				compare_fine = 'X;
				compare_coarse = 'X;
			end
		endcase
	end

	wire compare_match = (r_fine == compare_fine && r_coarse == compare_coarse);
	wire inc_phase = enable && compare_match;

	always_ff @(posedge clk) begin
		r_fine <= next_fine; // includes reset
		if (reset) begin
			r_coarse <= 0;
			phase <= `XPHASE_SYNC;
		end else begin
			r_coarse <= sum_coarse[COARSE_BITS-1:0];
			phase <= phase + inc_phase;
		end
	end
	assign carry_coarse = sum_coarse[COARSE_BITS];


	reg [BITS-1:0] coarse_term; // not a register
	generate
		if (FINE_PERIOD == 100) begin
			always_comb begin
				case (r_coarse)
					/*
					0: coarse_term = 0;
					1: coarse_term = 100*1;
					2: coarse_term = 100*2;
					3: coarse_term = 100*3;
					4: coarse_term = 100*4;
					5: coarse_term = 100*5;
					6: coarse_term = 100*6;
					*/
					// Only the factors needed for 128 to 639+128 = 767, subtracting 128 from the result
					1: coarse_term = 100*1 - 128;
					2: coarse_term = 100*2 - 128;
					3: coarse_term = 100*3 - 128;
					4: coarse_term = 100*4 - 128;
					5: coarse_term = 100*5 - 128;
					6: coarse_term = 100*6 - 128;
					7: coarse_term = 100*7 - 128;
					default: coarse_term = 'X;
				endcase
			end
		end
		if (FINE_PERIOD == 50) begin
			always_comb begin
				case (r_coarse)
/*
					0:  coarse_term = 0;
					1:  coarse_term = 50*1;
					2:  coarse_term = 50*2;
					3:  coarse_term = 50*3;
					4:  coarse_term = 50*4;
					5:  coarse_term = 50*5;
					6:  coarse_term = 50*6;
					7:  coarse_term = 50*7;
					8:  coarse_term = 50*8;
					9:  coarse_term = 50*9;
					10: coarse_term = 50*10;
					11: coarse_term = 50*11;
					12: coarse_term = 50*12;
*/
					// Only the factors needed for 128 to 639+128 = 767, subtracting 128 from the result
					2:  coarse_term = 50*2  - 128;
					3:  coarse_term = 50*3  - 128;
					4:  coarse_term = 50*4  - 128;
					5:  coarse_term = 50*5  - 128;
					6:  coarse_term = 50*6  - 128;
					7:  coarse_term = 50*7  - 128;
					8:  coarse_term = 50*8  - 128;
					9:  coarse_term = 50*9  - 128;
					10: coarse_term = 50*10 - 128;
					11: coarse_term = 50*11 - 128;
					12: coarse_term = 50*12 - 128;
					13: coarse_term = 50*13 - 128;
					14: coarse_term = 50*14 - 128;
					15: coarse_term = 50*15 - 128;

					default: coarse_term = 'X;
				endcase
			end
		end
	endgenerate
	assign x = coarse_term + r_fine;


	assign x_fine = r_fine;
	assign x_coarse = r_coarse;

	assign active = (phase == `XPHASE_ACTIVE);
	assign sync   = (phase == `XPHASE_SYNC);

	assign new_vga_line = sync && inc_phase;
	//assign new_line = (phase == `XPHASE_BP) && inc_phase;
	assign new_line = carry_coarse;
	assign active_done = active && inc_phase;
endmodule



module axis_scan_y2 #( parameter Y_STEPS = 525, Y_SAT_BITS = 9 ) (
		input wire clk,
		input wire reset,
		input wire enable,

		output wire saturated,
		output wire [Y_SAT_BITS-1:0] y_sat, y_wrap,
		output wire active, sync,

		output wire new_frame
	);

	localparam Y_BITS = $clog2(Y_STEPS);

	reg [Y_BITS-1:0] y;
	reg [1:0] phase;

	wire restart = enable && (y == Y_STEPS - 1);
	wire [Y_BITS-1:0] y_sum = y + enable;
	wire [Y_BITS-1:0] next_y = (restart || reset) ? '0 : y_sum;


	reg [Y_BITS-1:0] compare; // not a register
	always_comb begin
		case (phase)
			`YPHASE_ACTIVE: compare = 479;
			`YPHASE_FP: compare = 489;
			`YPHASE_SYNC: compare = 491;
			`YPHASE_BP: compare = 524;
			default: compare = 'X;
		endcase
	end

	wire compare_match = (y == compare);
	wire inc_phase = enable && compare_match;

	always_ff @(posedge clk) begin
		if (reset) begin
			y <= 0;
			phase <= `YPHASE_ACTIVE;
		end else begin
			y <= next_y;
			phase <= phase + inc_phase;
		end
	end

	assign y_wrap = y[Y_SAT_BITS-1:0];
	assign saturated = (y[Y_BITS-1:Y_SAT_BITS] != '0);
	assign y_sat = saturated ? '0 : y[Y_SAT_BITS-1:0];

	assign active = (phase == `YPHASE_ACTIVE);
	assign sync   = (phase == `YPHASE_SYNC);

	// Increase the frame counter when we start saturating y to zero
	assign new_frame = next_y[Y_SAT_BITS] && !y[Y_SAT_BITS];
endmodule



module raster_scan2 #(parameter X_FINE_PERIOD = 100, X_COARSE_BITS = 3, Y_STEPS = 525, Y_SAT_BITS = 9) (
		input wire clk,
		input wire reset,
		input wire enable,

		output wire [$clog2(X_FINE_PERIOD)-1:0] x_fine,
		output wire [X_COARSE_BITS-1:0] x_coarse,
		output wire [X_COARSE_BITS + $clog2(X_FINE_PERIOD)-1:0] x,
		output wire carry_fine, carry_coarse,
		output wire h_active, hsync,
		output wire new_line, h_active_done,

		output wire saturated,
		output wire [Y_SAT_BITS-1:0] y_sat, y_wrap,
		output wire v_active, vsync,

		output wire new_frame, // goes high when y_sat wraps around, normally 13 lines before the new active region

		output wire active
	);

	wire new_vga_line;
	axis_scan_x2 #(.FINE_PERIOD(X_FINE_PERIOD), .COARSE_BITS(X_COARSE_BITS)) x_scan(
		.clk(clk), .reset(reset), .enable(enable),
		.x_fine(x_fine), .x_coarse(x_coarse), .x(x),
		.carry_coarse (carry_coarse), .carry_fine  (carry_fine),
		.active(h_active), .sync(hsync),
		.new_line(new_line), .new_vga_line(new_vga_line), .active_done(h_active_done)
	);

	wire vsync0;
	axis_scan_y2 #(.Y_STEPS(Y_STEPS), .Y_SAT_BITS(Y_SAT_BITS)) scan_y(
		.clk(clk), .reset(reset), .enable(new_line),
		.saturated(saturated), .y_sat(y_sat), .y_wrap(y_wrap),
		.active(v_active), .sync(vsync0),
		.new_frame(new_frame)
	);

	reg r_vsync;
	always_ff @(posedge clk) begin
		if (reset || new_vga_line) r_vsync <= vsync0;
	end
	assign vsync = r_vsync;

	assign active = h_active && v_active;
endmodule
