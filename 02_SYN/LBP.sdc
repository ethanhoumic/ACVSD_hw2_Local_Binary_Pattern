set CYCLE_A 100.0
set CYCLE_B 1.0

create_clock -name "clk_A"  -period $CYCLE_A   clk_A
create_clock -name "clk_B"  -period $CYCLE_B   clk_B

set_dont_touch_network      [get_clocks *]
set_fix_hold                [get_clocks *]
set_clock_uncertainty  0.1  [get_clocks *]
set_clock_latency      0.5  [get_clocks *]
set_ideal_network           [get_ports clk*]
set_clock_transition   0.1  [get_clocks *]

set_input_delay 0 -clock clk_A clk_A
set_input_delay 0 -clock clk_B clk_B

set_input_delay 0 -clock clk_B [remove_from_collection [all_inputs] {clk_A clk_B rst start}]
set_input_delay 1.0 -clock clk_A rst    
set_input_delay 1.0 -clock clk_A start 

set_output_delay 0.5  -clock clk_B [remove_from_collection [all_outputs] {finish}]
set_output_delay 0.5  -clock clk_A {finish}

set_drive        1        [all_inputs]
set_load         0.05     [all_outputs]

set_clock_groups -asynchronous -group {clk_A} -group {clk_B}
# Add your Clock Domain Crossing constraint here
# Hint: set_false_path or set_clock_group