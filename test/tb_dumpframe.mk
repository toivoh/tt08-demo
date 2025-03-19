# Makefile
# See https://docs.cocotb.org/en/stable/quickstart.html for more info

# defaults
SIM ?= icarus
TOPLEVEL_LANG ?= verilog
SRC_DIR = $(PWD)/../src
#PROJECT_SOURCES = project.v demo.sv sine_table_generated.v logo_table_generated.v graphics.sv raster_scan2.sv tinysynth.sv alu_code_generated.v #memories.sv
#PROJECT_SOURCES = project.v demo.sv sine_table_generated2.v logo_table_generated.v graphics.sv raster_scan2.sv tinysynth.sv alu_code_generated.v #memories.sv
PROJECT_SOURCES = project.v demo.sv sine_table_generated3.v logo_table_generated.v graphics.sv raster_scan2.sv tinysynth.sv alu_code_generated.v #memories.sv

ifneq ($(GATES),yes)

# RTL simulation:
SIM_BUILD				= sim_build/rtl
VERILOG_SOURCES += $(addprefix $(SRC_DIR)/,$(PROJECT_SOURCES))
COMPILE_ARGS 		+= -I$(SRC_DIR)

else

# Gate level simulation:
SIM_BUILD				= sim_build/gl
COMPILE_ARGS    += -DGL_TEST
COMPILE_ARGS    += -DFUNCTIONAL
COMPILE_ARGS    += -DUSE_POWER_PINS
COMPILE_ARGS    += -DSIM
COMPILE_ARGS    += -DUNIT_DELAY=\#1
VERILOG_SOURCES += $(PDK_ROOT)/ihp-sg13g2/libs.ref/sg13g2_io/verilog/sg13g2_io.v
VERILOG_SOURCES += $(PDK_ROOT)/ihp-sg13g2/libs.ref/sg13g2_stdcell/verilog/sg13g2_stdcell.v

# this gets copied in by the GDS action workflow
VERILOG_SOURCES += $(PWD)/gate_level_netlist.v

endif

# Include the testbench sources:
VERILOG_SOURCES += $(PWD)/tb_dumpframe.v
TOPLEVEL = tb_dumpframe

# MODULE is the basename of the Python test file
MODULE = tb_dumpframe

# include cocotb's make rules to take care of the simulator setup
include $(shell cocotb-config --makefiles)/Makefile.sim
