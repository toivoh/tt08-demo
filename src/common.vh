/*
 * Copyright (c) 2024 Toivo Henningsson <toivo.h.h@gmail.com>
 * SPDX-License-Identifier: Apache-2.0
 */

`include "sine_table_generated.vh"


`define FINAL_COLOR_CHANNEL_BITS 2
`define COLOR_CHANNEL_BITS 4
`define COLOR_DITHER_BITS (`COLOR_CHANNEL_BITS - `FINAL_COLOR_CHANNEL_BITS)
`define COLOR_BITS (3*`COLOR_CHANNEL_BITS)

`define DPHASE_BITS 11
`define PHASE_BITS (`DPHASE_BITS + 5)

`define ZG_BITS (`SINE_OUT_BITS+2)
`define COSAPPR_BITS 9
