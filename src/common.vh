/*
 * Copyright (c) 2024 Toivo Henningsson <toivo.h.h@gmail.com>
 * SPDX-License-Identifier: Apache-2.0
 */

`include "sine_table_generated.vh"


`define FINAL_COLOR_CHANNEL_BITS 2
`define COLOR_CHANNEL_BITS 4
`define COLOR_DITHER_BITS (`COLOR_CHANNEL_BITS - `FINAL_COLOR_CHANNEL_BITS)
`define COLOR_BITS (3*`COLOR_CHANNEL_BITS)

`define DX_BITS 9
`define X_BITS (`DX_BITS + 7)
`define DPHASE_BITS 11
`define PHASE_BITS (`DPHASE_BITS + 5)

`define DZ_BITS 9

//`define USE_EXTRA_Z_RANGE // define iff Z_BITS > Z_ZG_BITS
//`define Z_BITS (15+1+1)
`define Z_BITS 15
`define Z_ZG_BITS 15

`define T_BITS 10 // TODO: do we need this much?
`define MAX_DZ_T_BITS 10

`define ZG_SHR 0
`define ZG_BITS (`SINE_OUT_BITS+2-`ZG_SHR)
`define COSAPPR_BITS 9

`define NSTEP_BITS 2
`define NSTEP_PERIOD_BITS 5


`define USE_LOGO
//`define USE_OCCLUSION
`define USE_GRAPHICS_JUMPS
`define USE_FM


`ifndef FPGA

//`define USE_DPHASE_LATCHES // untested, doesn't save much area

`endif


`ifdef USE_FM
`define NUM_WAVE_INDS 4
`else
`define NUM_WAVE_INDS 3
`endif
