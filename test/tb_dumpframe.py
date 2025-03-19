# SPDX-FileCopyrightText: © 2024 Toivo Henningsson
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer, ClockCycles


@cocotb.test()
async def test_dumpframe(dut):

	preserved = True
	try:
		demo_top = dut.user_project.dtop
	except AttributeError:
		preserved = False

	#NUM_LINES = 25
	NUM_LINES = 525
	CYCLES_PER_LINE = 1600

	#section, subsect, subsubsect, sub3sect, sub_frames = 0, 0, 0, 0, 0; NUM_LINES = 25
	#section, subsect, subsubsect, sub3sect, sub_frames = 0, 0, 2, 1, 5 # fade in
	#section, subsect, subsubsect, sub3sect, sub_frames = 0, 1, 2, 0, 0 # logo fade-in
	#section, subsect, subsubsect, sub3sect, sub_frames = 1, 2, 1, 0, 0
	#section, subsect, subsubsect, sub3sect, sub_frames = 2, 1, 3, 3, 0
	#section, subsect, subsubsect, sub3sect, sub_frames = 2, 3, 3, 0, 3 # logo rotation
	section, subsect, subsubsect, sub3sect, sub_frames = 2, 3, 3, 0, 3; NUM_LINES = 525*2 # logo rotation x2
	#section, subsect, subsubsect, sub3sect, sub_frames = 3, 1, 2, 1, 0
	#section, subsect, subsubsect, sub3sect, sub_frames = 3, 3, 3, 3, 31; NUM_LINES = 525*2
	#section, subsect, subsubsect, sub3sect, sub_frames = 4, 3, 0, 0, 27
	#section, subsect, subsubsect, sub3sect, sub_frames = 5, 1, 2, 2, 11 # Logo fade-out, everything else is black, music is silent, including bass

	assert 0 <= sub_frames <= 31

	fc = (section << 11) | (subsect << 9) | (subsubsect << 7) | (sub3sect << 5) | sub_frames
	assert fc < 6*2048
	print("Starting frame_counter =", hex(fc))


	#output_filename = "rtl-output-data.txt" if preserved else "gl-output-data.txt"
	prefix = "rtl" if preserved else "gl"
	output_filename = f"{prefix}-output-{section}-{subsect}-{subsubsect}-{sub3sect}-{sub_frames}-l{NUM_LINES}-data.txt"
	print("output_filename =", output_filename)


	dut._log.info("start")
	clock = Clock(dut.clk, 2, units="us")
	cocotb.start_soon(clock.start())

	# Reset
	dut.ena.value = 1
	dut.ui_in.value = 0
	dut.uio_in.value = 0
	dut.rst_n.value = 0
	await ClockCycles(dut.clk, 10)
	# Skip forward to the desired frame
	dut.ui_in.value = 128
	#await ClockCycles(dut.clk, fc)
	#dut.ui_in.value = 0
	#dut.rst_n.value = 1
	await ClockCycles(dut.clk, fc-1)
	dut.rst_n.value = 1
	await ClockCycles(dut.clk, 1)
	dut.ui_in.value = 0
	await ClockCycles(dut.clk, 3)

	with open(output_filename, "w") as text_file:
		for j in range(NUM_LINES):
			for i in range(CYCLES_PER_LINE):
				out = dut.out.value.integer
				text_file.write(f"{out} ")

				await ClockCycles(dut.clk, 1)
			text_file.write("\n")
