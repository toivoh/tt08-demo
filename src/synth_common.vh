
`define A_SRC_BITS 3
`define A_ZERO           3'd0
`define A_ONE            3'd1
`define A_99             3'd2
`define A_A              3'd3
`define A_TRI            3'd4
`define A_OSHIFTED       3'd5
//`define A_OSHIFTED_CHORD 3'd6
`define A_SHR1           3'd6
`define A_REV            3'd7


`define NUM_ALU_REGS 7
`define S_NONREG_BASE 7 // Must be >= NUM_ALU_REGS

`define S_SRC_BITS 4
// The first NUM_ALU_REGS sources map to the registers
`define S_PHASE 0 // The phase registers should be first because the same numbering is used for octaves
`define S_PHASE_DRUMS 1
`define S_PHASE_BASS 2
`define S_PHASE_LEAD 3
`define S_B 4
`define S_OUTPUT_ACC 5
`define S_OUTPUT 6

// The four mantissas must be consecutive
`define S_MANTISSA       (`S_NONREG_BASE + 0)
`define S_MANTISSA_DRUMS (`S_NONREG_BASE + 1)
`define S_MANTISSA_BASS  (`S_NONREG_BASE + 2)
`define S_MANTISSA_LEAD  (`S_NONREG_BASE + 3)
`define S_PHASEINC       (`S_NONREG_BASE + 4)
`define S_OC_SHIFTED     (`S_NONREG_BASE + 5)
`define S_OCT_COUNTER    (`S_NONREG_BASE + 6)
`define S_A_SIGN         (`S_NONREG_BASE + 7)
`define S_ZERO           (`S_NONREG_BASE + 8)

`define TAG_BITS        3
`define TAG_RAISE_DRUM  1
`define TAG_DETUNE_LEAD 2
`define TAG_CHORD_MORE  3
`define TAG_LEAD_ECHO   4
`define TAG_REDUCE_BASS 5
`define TAG_INVERT_OUT  6
`define TAG_SQUARE_LEAD 7


`define MOP_FLAG_BITS 5


`define SHIFT_COUNT_BITS 3
`define MIN_OC_SHIFT 8
`define CHORD_EXTRA_OSHIFT 3

`define PLAYER_CONTROL_BITS 9
`define PC_CHORDS_ON     0
`define PC_DETUNE_LEAD   1
`define PC_SIMPLE_BASS   2
`define PC_MODULATE      3
`define PC_RESOLUTION    4
`define PC_PRERESOLUTION 5
`define PC_SILENCE       6
`define PC_RAISE_BASS    7
`define PC_SQUARE_LEAD   8

`define EXT_CONTROL_BITS 4
`define EC_VIS_BASS_OFF 0
`define EC_VIS_DRUMS_OFF 1
`define EC_KEEP_BASS_LOW 2
`define EC_PAUSE         3



`ifndef FPGA
`define USE_LATCHES
`define BUFFER_CLOCK_GATE
`endif

`define USE_ALU_REG_PRUNING
`define USE_SHARED_MANTISSA_TABLE

`define USE_LEAD_EMB
