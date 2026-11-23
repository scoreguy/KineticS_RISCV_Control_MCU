# Optional Vivado out-of-context synthesis. Not a board implementation.
set root [file normalize [file join [file dirname [info script]] ..]]
cd $root
file mkdir work/vivado
read_verilog -sv [list rtl/mac_core.sv rtl/mac_regs.sv]
synth_design -top mac_regs -part xc7z020clg400-1 -mode out_of_context
create_clock -name clk -period 8.000 [get_ports clk]
report_utilization -file docs/utilization_synth.rpt
report_timing_summary -file docs/timing_synth.rpt
write_checkpoint -force work/vivado/mac_regs_synth.dcp
