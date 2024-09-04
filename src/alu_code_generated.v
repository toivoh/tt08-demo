module alu_program(
		input wire [`PROG_ADDR_BITS-1:0] addr,

		output wire [`A_SRC_BITS-1:0] a_src,
		output wire [`S_SRC_BITS-1:0] s_src,
		output wire [`SHIFT_COUNT_BITS-1:0] shift,
		output wire [`MOP_FLAG_BITS-1:0] flags,
		output wire [`NUM_ALU_REGS-1:0] dmask,
		output wire [2:0] fasrc,
		output wire [`TAG_BITS-1:0] tag
	);

	localparam PROG_SIZE = 100;

	(* mem2reg *) reg [`A_SRC_BITS-1:0]       prog_a_src[PROG_SIZE];
	(* mem2reg *) reg [`S_SRC_BITS-1:0]       prog_s_src[PROG_SIZE];
	(* mem2reg *) reg [`SHIFT_COUNT_BITS-1:0] prog_shift[PROG_SIZE];
	(* mem2reg *) reg [`MOP_FLAG_BITS-1:0]    prog_flags[PROG_SIZE];
	(* mem2reg *) reg [`NUM_ALU_REGS-1:0]     prog_dmask[PROG_SIZE];
	(* mem2reg *) reg [2:0]                   prog_fasrc[PROG_SIZE];
	(* mem2reg *) reg [`TAG_BITS-1:0]         prog_tag[PROG_SIZE];

	assign a_src = prog_a_src[addr];
	assign s_src = prog_s_src[addr];
	assign shift = prog_shift[addr];
	assign flags = prog_flags[addr];
	assign dmask = prog_dmask[addr];
	assign fasrc = prog_fasrc[addr];
	assign tag   = prog_tag[addr];

	initial begin
		prog_a_src[0] = 1;	prog_s_src[0] = 13;	prog_shift[0] = 0;	prog_flags[0] = 6;	prog_dmask[0] = 0;	prog_fasrc[0] = 7;	prog_tag[0] = 0;
		prog_a_src[1] = 3;	prog_s_src[1] = 13;	prog_shift[1] = 0;	prog_flags[1] = 1;	prog_dmask[1] = 0;	prog_fasrc[1] = 7;	prog_tag[1] = 0;
		prog_a_src[2] = 0;	prog_s_src[2] = 0;	prog_shift[2] = 0;	prog_flags[2] = 6;	prog_dmask[2] = 0;	prog_fasrc[2] = 7;	prog_tag[2] = 0;
		prog_a_src[3] = 7;	prog_s_src[3] = 7;	prog_shift[3] = 0;	prog_flags[3] = 18;	prog_dmask[3] = 0;	prog_fasrc[3] = 7;	prog_tag[3] = 0;
		prog_a_src[4] = 3;	prog_s_src[4] = 11;	prog_shift[4] = 0;	prog_flags[4] = 6;	prog_dmask[4] = 0;	prog_fasrc[4] = 7;	prog_tag[4] = 0;
		prog_a_src[5] = 3;	prog_s_src[5] = 0;	prog_shift[5] = 0;	prog_flags[5] = 0;	prog_dmask[5] = 1;	prog_fasrc[5] = 7;	prog_tag[5] = 0;
		prog_a_src[6] = 3;	prog_s_src[6] = 0;	prog_shift[6] = 0;	prog_flags[6] = 0;	prog_dmask[6] = 16;	prog_fasrc[6] = 7;	prog_tag[6] = 0;
		prog_a_src[7] = 0;	prog_s_src[7] = 4;	prog_shift[7] = 2;	prog_flags[7] = 6;	prog_dmask[7] = 0;	prog_fasrc[7] = 0;	prog_tag[7] = 0;
		prog_a_src[8] = 3;	prog_s_src[8] = 4;	prog_shift[8] = 2;	prog_flags[8] = 6;	prog_dmask[8] = 0;	prog_fasrc[8] = 1;	prog_tag[8] = 0;
		prog_a_src[9] = 5;	prog_s_src[9] = 15;	prog_shift[9] = 0;	prog_flags[9] = 6;	prog_dmask[9] = 0;	prog_fasrc[9] = 7;	prog_tag[9] = 0;
		prog_a_src[10] = 6;	prog_s_src[10] = 15;	prog_shift[10] = 0;	prog_flags[10] = 6;	prog_dmask[10] = 0;	prog_fasrc[10] = 7;	prog_tag[10] = 0;
		prog_a_src[11] = 6;	prog_s_src[11] = 15;	prog_shift[11] = 0;	prog_flags[11] = 6;	prog_dmask[11] = 0;	prog_fasrc[11] = 7;	prog_tag[11] = 0;
		prog_a_src[12] = 6;	prog_s_src[12] = 15;	prog_shift[12] = 0;	prog_flags[12] = 6;	prog_dmask[12] = 0;	prog_fasrc[12] = 7;	prog_tag[12] = 0;
		prog_a_src[13] = 3;	prog_s_src[13] = 0;	prog_shift[13] = 0;	prog_flags[13] = 0;	prog_dmask[13] = 32;	prog_fasrc[13] = 7;	prog_tag[13] = 0;
		prog_a_src[14] = 0;	prog_s_src[14] = 4;	prog_shift[14] = 1;	prog_flags[14] = 6;	prog_dmask[14] = 0;	prog_fasrc[14] = 2;	prog_tag[14] = 0;
		prog_a_src[15] = 3;	prog_s_src[15] = 4;	prog_shift[15] = 3;	prog_flags[15] = 6;	prog_dmask[15] = 0;	prog_fasrc[15] = 3;	prog_tag[15] = 0;
		prog_a_src[16] = 5;	prog_s_src[16] = 15;	prog_shift[16] = 0;	prog_flags[16] = 6;	prog_dmask[16] = 0;	prog_fasrc[16] = 7;	prog_tag[16] = 0;
		prog_a_src[17] = 6;	prog_s_src[17] = 15;	prog_shift[17] = 0;	prog_flags[17] = 6;	prog_dmask[17] = 0;	prog_fasrc[17] = 7;	prog_tag[17] = 0;
		prog_a_src[18] = 6;	prog_s_src[18] = 15;	prog_shift[18] = 0;	prog_flags[18] = 6;	prog_dmask[18] = 0;	prog_fasrc[18] = 7;	prog_tag[18] = 0;
		prog_a_src[19] = 6;	prog_s_src[19] = 5;	prog_shift[19] = 0;	prog_flags[19] = 6;	prog_dmask[19] = 0;	prog_fasrc[19] = 7;	prog_tag[19] = 0;
		prog_a_src[20] = 3;	prog_s_src[20] = 0;	prog_shift[20] = 0;	prog_flags[20] = 0;	prog_dmask[20] = 32;	prog_fasrc[20] = 7;	prog_tag[20] = 3;
		prog_a_src[21] = 0;	prog_s_src[21] = 4;	prog_shift[21] = 2;	prog_flags[21] = 6;	prog_dmask[21] = 0;	prog_fasrc[21] = 4;	prog_tag[21] = 0;
		prog_a_src[22] = 3;	prog_s_src[22] = 4;	prog_shift[22] = 3;	prog_flags[22] = 6;	prog_dmask[22] = 0;	prog_fasrc[22] = 5;	prog_tag[22] = 0;
		prog_a_src[23] = 5;	prog_s_src[23] = 15;	prog_shift[23] = 0;	prog_flags[23] = 6;	prog_dmask[23] = 0;	prog_fasrc[23] = 7;	prog_tag[23] = 0;
		prog_a_src[24] = 6;	prog_s_src[24] = 15;	prog_shift[24] = 0;	prog_flags[24] = 6;	prog_dmask[24] = 0;	prog_fasrc[24] = 7;	prog_tag[24] = 0;
		prog_a_src[25] = 6;	prog_s_src[25] = 15;	prog_shift[25] = 0;	prog_flags[25] = 6;	prog_dmask[25] = 0;	prog_fasrc[25] = 7;	prog_tag[25] = 0;
		prog_a_src[26] = 6;	prog_s_src[26] = 5;	prog_shift[26] = 0;	prog_flags[26] = 6;	prog_dmask[26] = 0;	prog_fasrc[26] = 7;	prog_tag[26] = 0;
		prog_a_src[27] = 3;	prog_s_src[27] = 0;	prog_shift[27] = 0;	prog_flags[27] = 0;	prog_dmask[27] = 32;	prog_fasrc[27] = 7;	prog_tag[27] = 3;
		prog_a_src[28] = 0;	prog_s_src[28] = 0;	prog_shift[28] = 0;	prog_flags[28] = 6;	prog_dmask[28] = 0;	prog_fasrc[28] = 7;	prog_tag[28] = 0;
		prog_a_src[29] = 3;	prog_s_src[29] = 12;	prog_shift[29] = 6;	prog_flags[29] = 6;	prog_dmask[29] = 0;	prog_fasrc[29] = 7;	prog_tag[29] = 0;
		prog_a_src[30] = 3;	prog_s_src[30] = 0;	prog_shift[30] = 0;	prog_flags[30] = 0;	prog_dmask[30] = 16;	prog_fasrc[30] = 7;	prog_tag[30] = 0;
		prog_a_src[31] = 0;	prog_s_src[31] = 4;	prog_shift[31] = 2;	prog_flags[31] = 6;	prog_dmask[31] = 0;	prog_fasrc[31] = 0;	prog_tag[31] = 0;
		prog_a_src[32] = 3;	prog_s_src[32] = 4;	prog_shift[32] = 2;	prog_flags[32] = 6;	prog_dmask[32] = 0;	prog_fasrc[32] = 1;	prog_tag[32] = 0;
		prog_a_src[33] = 5;	prog_s_src[33] = 15;	prog_shift[33] = 0;	prog_flags[33] = 6;	prog_dmask[33] = 0;	prog_fasrc[33] = 7;	prog_tag[33] = 0;
		prog_a_src[34] = 6;	prog_s_src[34] = 15;	prog_shift[34] = 0;	prog_flags[34] = 6;	prog_dmask[34] = 0;	prog_fasrc[34] = 7;	prog_tag[34] = 0;
		prog_a_src[35] = 6;	prog_s_src[35] = 15;	prog_shift[35] = 0;	prog_flags[35] = 6;	prog_dmask[35] = 0;	prog_fasrc[35] = 7;	prog_tag[35] = 0;
		prog_a_src[36] = 6;	prog_s_src[36] = 5;	prog_shift[36] = 0;	prog_flags[36] = 6;	prog_dmask[36] = 0;	prog_fasrc[36] = 7;	prog_tag[36] = 0;
		prog_a_src[37] = 3;	prog_s_src[37] = 0;	prog_shift[37] = 0;	prog_flags[37] = 0;	prog_dmask[37] = 32;	prog_fasrc[37] = 7;	prog_tag[37] = 0;
		prog_a_src[38] = 0;	prog_s_src[38] = 4;	prog_shift[38] = 1;	prog_flags[38] = 6;	prog_dmask[38] = 0;	prog_fasrc[38] = 2;	prog_tag[38] = 0;
		prog_a_src[39] = 3;	prog_s_src[39] = 4;	prog_shift[39] = 3;	prog_flags[39] = 6;	prog_dmask[39] = 0;	prog_fasrc[39] = 3;	prog_tag[39] = 0;
		prog_a_src[40] = 5;	prog_s_src[40] = 15;	prog_shift[40] = 0;	prog_flags[40] = 6;	prog_dmask[40] = 0;	prog_fasrc[40] = 7;	prog_tag[40] = 0;
		prog_a_src[41] = 6;	prog_s_src[41] = 15;	prog_shift[41] = 0;	prog_flags[41] = 6;	prog_dmask[41] = 0;	prog_fasrc[41] = 7;	prog_tag[41] = 0;
		prog_a_src[42] = 6;	prog_s_src[42] = 15;	prog_shift[42] = 0;	prog_flags[42] = 6;	prog_dmask[42] = 0;	prog_fasrc[42] = 7;	prog_tag[42] = 0;
		prog_a_src[43] = 6;	prog_s_src[43] = 5;	prog_shift[43] = 0;	prog_flags[43] = 6;	prog_dmask[43] = 0;	prog_fasrc[43] = 7;	prog_tag[43] = 0;
		prog_a_src[44] = 3;	prog_s_src[44] = 0;	prog_shift[44] = 0;	prog_flags[44] = 0;	prog_dmask[44] = 32;	prog_fasrc[44] = 7;	prog_tag[44] = 3;
		prog_a_src[45] = 0;	prog_s_src[45] = 4;	prog_shift[45] = 2;	prog_flags[45] = 6;	prog_dmask[45] = 0;	prog_fasrc[45] = 4;	prog_tag[45] = 0;
		prog_a_src[46] = 3;	prog_s_src[46] = 4;	prog_shift[46] = 3;	prog_flags[46] = 6;	prog_dmask[46] = 0;	prog_fasrc[46] = 5;	prog_tag[46] = 0;
		prog_a_src[47] = 5;	prog_s_src[47] = 15;	prog_shift[47] = 0;	prog_flags[47] = 6;	prog_dmask[47] = 0;	prog_fasrc[47] = 7;	prog_tag[47] = 0;
		prog_a_src[48] = 6;	prog_s_src[48] = 15;	prog_shift[48] = 0;	prog_flags[48] = 6;	prog_dmask[48] = 0;	prog_fasrc[48] = 7;	prog_tag[48] = 0;
		prog_a_src[49] = 6;	prog_s_src[49] = 15;	prog_shift[49] = 0;	prog_flags[49] = 6;	prog_dmask[49] = 0;	prog_fasrc[49] = 7;	prog_tag[49] = 0;
		prog_a_src[50] = 6;	prog_s_src[50] = 5;	prog_shift[50] = 0;	prog_flags[50] = 6;	prog_dmask[50] = 0;	prog_fasrc[50] = 7;	prog_tag[50] = 0;
		prog_a_src[51] = 3;	prog_s_src[51] = 0;	prog_shift[51] = 0;	prog_flags[51] = 0;	prog_dmask[51] = 32;	prog_fasrc[51] = 7;	prog_tag[51] = 3;
		prog_a_src[52] = 1;	prog_s_src[52] = 13;	prog_shift[52] = 0;	prog_flags[52] = 6;	prog_dmask[52] = 0;	prog_fasrc[52] = 7;	prog_tag[52] = 0;
		prog_a_src[53] = 3;	prog_s_src[53] = 13;	prog_shift[53] = 2;	prog_flags[53] = 1;	prog_dmask[53] = 0;	prog_fasrc[53] = 7;	prog_tag[53] = 0;
		prog_a_src[54] = 0;	prog_s_src[54] = 2;	prog_shift[54] = 0;	prog_flags[54] = 6;	prog_dmask[54] = 0;	prog_fasrc[54] = 7;	prog_tag[54] = 0;
		prog_a_src[55] = 7;	prog_s_src[55] = 9;	prog_shift[55] = 0;	prog_flags[55] = 18;	prog_dmask[55] = 0;	prog_fasrc[55] = 7;	prog_tag[55] = 0;
		prog_a_src[56] = 3;	prog_s_src[56] = 11;	prog_shift[56] = 0;	prog_flags[56] = 6;	prog_dmask[56] = 0;	prog_fasrc[56] = 7;	prog_tag[56] = 0;
		prog_a_src[57] = 3;	prog_s_src[57] = 0;	prog_shift[57] = 0;	prog_flags[57] = 0;	prog_dmask[57] = 4;	prog_fasrc[57] = 7;	prog_tag[57] = 0;
		prog_a_src[58] = 3;	prog_s_src[58] = 0;	prog_shift[58] = 0;	prog_flags[58] = 0;	prog_dmask[58] = 16;	prog_fasrc[58] = 7;	prog_tag[58] = 0;
		prog_a_src[59] = 0;	prog_s_src[59] = 4;	prog_shift[59] = 3;	prog_flags[59] = 6;	prog_dmask[59] = 0;	prog_fasrc[59] = 7;	prog_tag[59] = 0;
		prog_a_src[60] = 4;	prog_s_src[60] = 15;	prog_shift[60] = 0;	prog_flags[60] = 6;	prog_dmask[60] = 0;	prog_fasrc[60] = 7;	prog_tag[60] = 0;
		prog_a_src[61] = 5;	prog_s_src[61] = 15;	prog_shift[61] = 0;	prog_flags[61] = 6;	prog_dmask[61] = 0;	prog_fasrc[61] = 7;	prog_tag[61] = 0;
		prog_a_src[62] = 6;	prog_s_src[62] = 15;	prog_shift[62] = 0;	prog_flags[62] = 6;	prog_dmask[62] = 0;	prog_fasrc[62] = 7;	prog_tag[62] = 5;
		prog_a_src[63] = 3;	prog_s_src[63] = 5;	prog_shift[63] = 0;	prog_flags[63] = 6;	prog_dmask[63] = 0;	prog_fasrc[63] = 7;	prog_tag[63] = 0;
		prog_a_src[64] = 3;	prog_s_src[64] = 0;	prog_shift[64] = 0;	prog_flags[64] = 0;	prog_dmask[64] = 32;	prog_fasrc[64] = 7;	prog_tag[64] = 0;
		prog_a_src[65] = 1;	prog_s_src[65] = 13;	prog_shift[65] = 0;	prog_flags[65] = 6;	prog_dmask[65] = 0;	prog_fasrc[65] = 7;	prog_tag[65] = 0;
		prog_a_src[66] = 3;	prog_s_src[66] = 13;	prog_shift[66] = 3;	prog_flags[66] = 1;	prog_dmask[66] = 0;	prog_fasrc[66] = 7;	prog_tag[66] = 0;
		prog_a_src[67] = 0;	prog_s_src[67] = 3;	prog_shift[67] = 0;	prog_flags[67] = 6;	prog_dmask[67] = 0;	prog_fasrc[67] = 7;	prog_tag[67] = 0;
		prog_a_src[68] = 7;	prog_s_src[68] = 10;	prog_shift[68] = 0;	prog_flags[68] = 18;	prog_dmask[68] = 0;	prog_fasrc[68] = 7;	prog_tag[68] = 0;
		prog_a_src[69] = 3;	prog_s_src[69] = 11;	prog_shift[69] = 0;	prog_flags[69] = 6;	prog_dmask[69] = 0;	prog_fasrc[69] = 7;	prog_tag[69] = 0;
		prog_a_src[70] = 3;	prog_s_src[70] = 0;	prog_shift[70] = 0;	prog_flags[70] = 0;	prog_dmask[70] = 8;	prog_fasrc[70] = 7;	prog_tag[70] = 0;
		prog_a_src[71] = 3;	prog_s_src[71] = 0;	prog_shift[71] = 0;	prog_flags[71] = 0;	prog_dmask[71] = 16;	prog_fasrc[71] = 7;	prog_tag[71] = 0;
		prog_a_src[72] = 0;	prog_s_src[72] = 4;	prog_shift[72] = 3;	prog_flags[72] = 6;	prog_dmask[72] = 0;	prog_fasrc[72] = 7;	prog_tag[72] = 0;
		prog_a_src[73] = 0;	prog_s_src[73] = 14;	prog_shift[73] = 0;	prog_flags[73] = 6;	prog_dmask[73] = 0;	prog_fasrc[73] = 7;	prog_tag[73] = 7;
		prog_a_src[74] = 4;	prog_s_src[74] = 15;	prog_shift[74] = 0;	prog_flags[74] = 6;	prog_dmask[74] = 0;	prog_fasrc[74] = 7;	prog_tag[74] = 7;
		prog_a_src[75] = 5;	prog_s_src[75] = 15;	prog_shift[75] = 0;	prog_flags[75] = 6;	prog_dmask[75] = 0;	prog_fasrc[75] = 7;	prog_tag[75] = 0;
		prog_a_src[76] = 6;	prog_s_src[76] = 15;	prog_shift[76] = 0;	prog_flags[76] = 6;	prog_dmask[76] = 0;	prog_fasrc[76] = 7;	prog_tag[76] = 4;
		prog_a_src[77] = 6;	prog_s_src[77] = 5;	prog_shift[77] = 0;	prog_flags[77] = 6;	prog_dmask[77] = 0;	prog_fasrc[77] = 7;	prog_tag[77] = 0;
		prog_a_src[78] = 3;	prog_s_src[78] = 0;	prog_shift[78] = 0;	prog_flags[78] = 0;	prog_dmask[78] = 32;	prog_fasrc[78] = 7;	prog_tag[78] = 0;
		prog_a_src[79] = 0;	prog_s_src[79] = 3;	prog_shift[79] = 0;	prog_flags[79] = 6;	prog_dmask[79] = 0;	prog_fasrc[79] = 7;	prog_tag[79] = 0;
		prog_a_src[80] = 3;	prog_s_src[80] = 12;	prog_shift[80] = 5;	prog_flags[80] = 6;	prog_dmask[80] = 0;	prog_fasrc[80] = 7;	prog_tag[80] = 0;
		prog_a_src[81] = 3;	prog_s_src[81] = 0;	prog_shift[81] = 0;	prog_flags[81] = 0;	prog_dmask[81] = 16;	prog_fasrc[81] = 7;	prog_tag[81] = 0;
		prog_a_src[82] = 0;	prog_s_src[82] = 4;	prog_shift[82] = 3;	prog_flags[82] = 6;	prog_dmask[82] = 0;	prog_fasrc[82] = 7;	prog_tag[82] = 0;
		prog_a_src[83] = 5;	prog_s_src[83] = 15;	prog_shift[83] = 0;	prog_flags[83] = 6;	prog_dmask[83] = 0;	prog_fasrc[83] = 7;	prog_tag[83] = 0;
		prog_a_src[84] = 6;	prog_s_src[84] = 15;	prog_shift[84] = 0;	prog_flags[84] = 6;	prog_dmask[84] = 0;	prog_fasrc[84] = 7;	prog_tag[84] = 4;
		prog_a_src[85] = 6;	prog_s_src[85] = 5;	prog_shift[85] = 0;	prog_flags[85] = 6;	prog_dmask[85] = 0;	prog_fasrc[85] = 7;	prog_tag[85] = 0;
		prog_a_src[86] = 3;	prog_s_src[86] = 0;	prog_shift[86] = 0;	prog_flags[86] = 0;	prog_dmask[86] = 32;	prog_fasrc[86] = 7;	prog_tag[86] = 2;
		prog_a_src[87] = 3;	prog_s_src[87] = 0;	prog_shift[87] = 0;	prog_flags[87] = 0;	prog_dmask[87] = 0;	prog_fasrc[87] = 7;	prog_tag[87] = 0;
		prog_a_src[88] = 1;	prog_s_src[88] = 13;	prog_shift[88] = 0;	prog_flags[88] = 6;	prog_dmask[88] = 0;	prog_fasrc[88] = 7;	prog_tag[88] = 0;
		prog_a_src[89] = 3;	prog_s_src[89] = 13;	prog_shift[89] = 1;	prog_flags[89] = 1;	prog_dmask[89] = 0;	prog_fasrc[89] = 7;	prog_tag[89] = 0;
		prog_a_src[90] = 0;	prog_s_src[90] = 1;	prog_shift[90] = 0;	prog_flags[90] = 6;	prog_dmask[90] = 0;	prog_fasrc[90] = 7;	prog_tag[90] = 0;
		prog_a_src[91] = 7;	prog_s_src[91] = 8;	prog_shift[91] = 0;	prog_flags[91] = 18;	prog_dmask[91] = 0;	prog_fasrc[91] = 7;	prog_tag[91] = 0;
		prog_a_src[92] = 3;	prog_s_src[92] = 11;	prog_shift[92] = 0;	prog_flags[92] = 6;	prog_dmask[92] = 0;	prog_fasrc[92] = 7;	prog_tag[92] = 0;
		prog_a_src[93] = 3;	prog_s_src[93] = 0;	prog_shift[93] = 0;	prog_flags[93] = 0;	prog_dmask[93] = 2;	prog_fasrc[93] = 7;	prog_tag[93] = 0;
		prog_a_src[94] = 3;	prog_s_src[94] = 1;	prog_shift[94] = 0;	prog_flags[94] = 6;	prog_dmask[94] = 0;	prog_fasrc[94] = 7;	prog_tag[94] = 1;
		prog_a_src[95] = 4;	prog_s_src[95] = 15;	prog_shift[95] = 0;	prog_flags[95] = 6;	prog_dmask[95] = 0;	prog_fasrc[95] = 7;	prog_tag[95] = 0;
		prog_a_src[96] = 5;	prog_s_src[96] = 5;	prog_shift[96] = 0;	prog_flags[96] = 6;	prog_dmask[96] = 0;	prog_fasrc[96] = 7;	prog_tag[96] = 0;
		prog_a_src[97] = 3;	prog_s_src[97] = 0;	prog_shift[97] = 0;	prog_flags[97] = 0;	prog_dmask[97] = 32;	prog_fasrc[97] = 7;	prog_tag[97] = 0;
		prog_a_src[98] = 2;	prog_s_src[98] = 5;	prog_shift[98] = 0;	prog_flags[98] = 22;	prog_dmask[98] = 0;	prog_fasrc[98] = 7;	prog_tag[98] = 6;
		prog_a_src[99] = 3;	prog_s_src[99] = 0;	prog_shift[99] = 0;	prog_flags[99] = 0;	prog_dmask[99] = 64;	prog_fasrc[99] = 7;	prog_tag[99] = 0;
	end
endmodule
