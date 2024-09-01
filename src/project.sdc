read_sdc $::env(SCRIPTS_DIR)/base.sdc

set_input_delay 1.5 -clock [get_clocks $::env(CLOCK_PORT)] {rst_n}
set_input_delay 1.5 -clock [get_clocks $::env(CLOCK_PORT)] {ui_in}
#set_output_delay 0 -clock [get_clocks $::env(CLOCK_PORT)] {uo_out}
#set_output_delay 0 -clock [get_clocks $::env(CLOCK_PORT)] {uio_out}
