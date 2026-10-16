## ============================================================
## Vivado TCL Script — PYNQ-Z2 Full Implementation Flow
## Usage: vivado -mode batch -source run_vivado_pynq.tcl
## Or paste into Vivado TCL console section by section
## ============================================================

## ------------------------------------------------------------
## 1. PROJECT SETUP
## Part: xc7z020clg400-1 (Zynq 7020, CLG400 package, -1 speed)
## This is the chip on the PYNQ-Z2.
## Different from Basys3's xc7a35tcpg236-1 (Artix-7 35T)
## The Zynq 7020 has ~twice the LUTs and a harder speed grade.
## ------------------------------------------------------------
set project_name "riscv_pynqz2"
set part_number  "xc7z020clg400-1"

create_project $project_name ./vivado_proj -part $part_number -force

## Add all RTL sources
add_files [glob ./rtl/*.v]

## Add PYNQ-Z2 constraints (NOT basys3.xdc)
add_files -fileset constrs_1 ./constraints/pynq_z2.xdc

## Set top module
set_property top riscv_cpu [current_fileset]

## Tell Vivado where imem.hex lives (must be in project directory or sim search path)
set_property include_dirs [list [get_property directory [current_project]]] [current_fileset]

## ------------------------------------------------------------
## 2. SYNTHESIS
## ------------------------------------------------------------
puts "=== Running Synthesis ==="
launch_runs synth_1 -jobs 4
wait_on_run synth_1

if {[get_property PROGRESS [get_runs synth_1]] != "100%"} {
    error "Synthesis FAILED — check Messages panel"
}
puts "Synthesis complete."

open_run synth_1 -name synth_1
report_utilization -file ./reports/utilization_synth.rpt
report_timing_summary -file ./reports/timing_synth.rpt

## ------------------------------------------------------------
## 3. IMPLEMENTATION
## ------------------------------------------------------------
puts "=== Running Implementation (Place and Route) ==="
launch_runs impl_1 -jobs 4
wait_on_run impl_1

if {[get_property PROGRESS [get_runs impl_1]] != "100%"} {
    error "Implementation FAILED — check Messages panel"
}
puts "Implementation complete."

open_run impl_1 -name impl_1

## ------------------------------------------------------------
## 4. TIMING REPORTS
## On PYNQ-Z2 (Zynq 7020, -1 speed grade) at 125 MHz:
##   WNS > 0 → timing met — this CPU will almost certainly pass
##   Zynq 7020 is faster than Basys3's Artix-7 35T
##   Typical WNS at 125 MHz: ~+2 to +3 ns for a single-cycle RV32I
## ------------------------------------------------------------
puts "=== Generating Timing Reports ==="

report_timing_summary \
    -delay_type min_max \
    -report_unconstrained \
    -check_timing_verbose \
    -max_paths 10 \
    -input_pins \
    -file ./reports/timing_summary.rpt

report_timing \
    -from [get_cells {regfile/regs*}] \
    -to   [get_cells {regfile/regs*}] \
    -delay_type max \
    -max_paths 5 \
    -sort_by slack \
    -file ./reports/timing_critical_path.rpt

report_timing \
    -delay_type min \
    -max_paths 5 \
    -sort_by slack \
    -file ./reports/timing_hold.rpt

report_clock_interaction -file ./reports/clock_interaction.rpt

## ------------------------------------------------------------
## 5. UTILIZATION REPORT
## ------------------------------------------------------------
report_utilization \
    -hierarchical \
    -file ./reports/utilization_impl.rpt

puts ""
puts "======================================================"
puts " TIMING SUMMARY"
puts "======================================================"
set wns [get_property SLACK [get_timing_paths -max_paths 1 -nworst 1 -setup]]
set whs [get_property SLACK [get_timing_paths -max_paths 1 -nworst 1 -hold]]
puts "  Setup WNS: $wns ns"
puts "  Hold  WHS: $whs ns"

if {$wns >= 0 && $whs >= 0} {
    puts "  STATUS: TIMING MET at 125 MHz on PYNQ-Z2"
} else {
    puts "  STATUS: TIMING VIOLATED"
    puts "  Fix: change clock period in pynq_z2.xdc to 10.000 (100 MHz)"
}
puts "======================================================"

report_power -file ./reports/power.rpt

## ------------------------------------------------------------
## 6. GENERATE BITSTREAM
## Output: riscv_cpu.bit
## To program: Hardware Manager → Open Target → Auto Connect
##             Program Device → select riscv_cpu.bit
## Note: On PYNQ-Z2, you can also load via Jupyter if PYNQ OS
## is installed, but direct JTAG from Vivado is simpler here.
## ------------------------------------------------------------
if {$wns >= 0} {
    puts "=== Generating Bitstream ==="
    launch_runs impl_1 -to_step write_bitstream -jobs 4
    wait_on_run impl_1
    puts "Bitstream: ./vivado_proj/$project_name.runs/impl_1/riscv_cpu.bit"
    puts ""
    puts "To program PYNQ-Z2:"
    puts "  1. Connect micro-USB cable (PROG/UART port)"
    puts "  2. Vivado Hardware Manager → Open Target → Auto Connect"
    puts "  3. Program Device → select riscv_cpu.bit"
    puts "  4. Watch LD0-LD3: after loop completes, all 4 LEDs light up (x10=15)"
    puts "  5. After double_it returns: x10=14, LD0 goes off"
    puts "  6. Press BTN0 to reset and watch the sequence again"
}

puts "=== Flow complete. Check ./reports/ ==="
