## ============================================================
## PYNQ-Z2 (Zynq XC7Z020-CLG400-1) Constraints for RV32I CPU
## Vivado XDC format
##
## Board IO available for PL (Programmable Logic):
##   4 green LEDs  : LD0-LD3
##   2 slide switches : SW0-SW1
##   4 push buttons   : BTN0-BTN3
##   125 MHz PL clock : H16
## ============================================================

## ------------------------------------------------------------
## CLOCK — 125 MHz from on-board oscillator (Ethernet PHY ref) → H16
## This feeds the PL directly — no PS required.
## Period = 8.000 ns for 125 MHz
## If timing fails, change to 10.000 (100 MHz) or 20.000 (50 MHz)
## ------------------------------------------------------------
set_property -dict { PACKAGE_PIN H16  IOSTANDARD LVCMOS33 } [get_ports { clk }]
create_clock -add -name sys_clk_pin -period 8.000 -waveform {0.000 4.000} [get_ports { clk }]

## To target 100 MHz (safer / closer to Basys3 original):
## set_property -dict { PACKAGE_PIN H16  IOSTANDARD LVCMOS33 } [get_ports { clk }]
## create_clock -add -name sys_clk_pin -period 10.000 -waveform {0.000 5.000} [get_ports { clk }]

## ------------------------------------------------------------
## RESET — BTN0 (D19) — press to reset the CPU
## ------------------------------------------------------------
set_property -dict { PACKAGE_PIN D19  IOSTANDARD LVCMOS33 } [get_ports { rst }]
set_false_path -from [get_ports rst]

## ------------------------------------------------------------
## LEDs — LD0..LD3 show debug_reg_x10[3:0]  (lower 4 bits of a0)
##
## The program accumulates 1+2+3+4+5 = 15 = 0b1111
## So after the loop, all 4 LEDs should be ON.
## After the JAL to double_it(7), a0 = 14 = 0b1110
## so LD3=1 LD2=1 LD1=1 LD0=0 — you can observe the change live.
## ------------------------------------------------------------
set_property -dict { PACKAGE_PIN R14  IOSTANDARD LVCMOS33 } [get_ports { debug_reg_x10[0] }]
set_property -dict { PACKAGE_PIN P14  IOSTANDARD LVCMOS33 } [get_ports { debug_reg_x10[1] }]
set_property -dict { PACKAGE_PIN N16  IOSTANDARD LVCMOS33 } [get_ports { debug_reg_x10[2] }]
set_property -dict { PACKAGE_PIN M14  IOSTANDARD LVCMOS33 } [get_ports { debug_reg_x10[3] }]

## ------------------------------------------------------------
## SWITCHES — SW0 and SW1 (not connected to CPU logic currently)
## Uncomment and wire these in riscv_cpu.v if you want to use them
## e.g. SW0 = manual step clock, SW1 = display select
## ------------------------------------------------------------
## set_property -dict { PACKAGE_PIN M20  IOSTANDARD LVCMOS33 } [get_ports { sw[0] }]
## set_property -dict { PACKAGE_PIN M19  IOSTANDARD LVCMOS33 } [get_ports { sw[1] }]

## ------------------------------------------------------------
## BUTTONS BTN1-BTN3 (not connected — available for future use)
## BTN0 is already used as rst above
## BTN1: D20   BTN2: L20   BTN3: L19
## ------------------------------------------------------------
## set_property -dict { PACKAGE_PIN D20  IOSTANDARD LVCMOS33 } [get_ports { btn[1] }]
## set_property -dict { PACKAGE_PIN L20  IOSTANDARD LVCMOS33 } [get_ports { btn[2] }]
## set_property -dict { PACKAGE_PIN L19  IOSTANDARD LVCMOS33 } [get_ports { btn[3] }]

## ------------------------------------------------------------
## TIMING HELPERS
## ------------------------------------------------------------
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property MAX_FANOUT 50 [get_cells -hier -filter {PRIMITIVE_TYPE =~ FLOP*}]

## ------------------------------------------------------------
## CONFIGURATION — Zynq PL bank voltage
## ------------------------------------------------------------
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]
