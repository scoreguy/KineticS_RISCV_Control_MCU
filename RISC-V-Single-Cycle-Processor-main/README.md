# RV32I Single-Cycle CPU

Complete implementation of a RISC-V 32-bit single-cycle CPU in Verilog.
All 37 RV32I base instructions implemented and tested.

---

## File structure

    rtl/
      riscv_cpu.v       Top-level: wires all modules together
      alu.v             32-bit ALU — all 12 operations
      alu_control.v     Decodes opcode+funct3+funct7 → alu_ctrl
      control_unit.v    Main control: opcode → all datapath signals
      register_file.v   32×32 regfile, 2 async reads, 1 sync write
      imm_gen.v         Sign-extends all 5 immediate formats
      instr_mem.v       256-word ROM (BRAM on FPGA)
      data_mem.v        256-word RAM, byte/half/word access
      branch_control.v  Branch condition evaluator (all 6 branches)
    tb/
      riscv_cpu_tb.v    Full testbench — 8 test groups, 25+ checks
    constraints/
      basys3.xdc        Vivado constraints: clock, IOs, timing
    scripts/
      run_vivado.tcl    Full Vivado flow: synth → impl → reports
    prog.s              Sample RISC-V assembly program

---

## Simulation (Icarus Verilog — free)

Install:
    Ubuntu:  sudo apt install iverilog gtkwave
    macOS:   brew install icarus-verilog gtkwave

Run testbench:
    cd riscv_singlecycle
    iverilog -o cpu_sim \
      tb/riscv_cpu_tb.v \
      rtl/riscv_cpu.v rtl/alu.v rtl/alu_control.v \
      rtl/control_unit.v rtl/register_file.v rtl/imm_gen.v \
      rtl/instr_mem.v rtl/data_mem.v rtl/branch_control.v
    vvp cpu_sim
    gtkwave cpu.vcd   # optional: view waveforms

Expected output:
    === TEST 1: R-type arithmetic ===
      PASS [ADD]  x3 = 0x00000011
      PASS [SUB]  x4 = 0x00000003
      ... (all PASS)
    === SUMMARY ===
    PASS: 25   FAIL: 0

---

## FPGA (Vivado + Basys3)

Option A — GUI:
  1. Open Vivado → Create Project → RTL Project
  2. Add Sources: all files in rtl/
  3. Add Constraints: constraints/basys3.xdc
  4. Set Top Module: riscv_cpu
  5. Run Synthesis
  6. Run Implementation
  7. Open Timing Summary report — check WNS >= 0
  8. Generate Bitstream → Program Device

Option B — TCL batch:
    vivado -mode batch -source scripts/run_vivado.tcl
    cat reports/timing_summary.rpt   # check WNS

---

## Timing analysis — what to look for

After implementation, open Reports → Timing Summary.
The key number is WNS (Worst Negative Slack):

  WNS >= 0  →  TIMING MET. Your CPU works at 100 MHz.
  WNS < 0   →  TIMING VIOLATION. Fixes:

    1. Easy:  Change clock to 50 MHz in basys3.xdc:
              create_clock -period 20.000 [get_ports clk]

    2. Better: Find the critical path in timing_critical_path.rpt
               It will show something like:
                 reg_file → ALU (carry chain) → reg_file
               Insert a pipeline register to break it.

    3. Code:   The 32-bit ripple carry in ADD is usually the
               critical path. Vivado maps + to CARRY8 primitives
               automatically — check the synthesized schematic.

Typical results on Basys3 (Artix-7 -1 speed grade):
  50  MHz:  WNS ~+4.0 ns  (very comfortable)
  100 MHz:  WNS ~+1.5 ns  (usually passes)
  125 MHz:  WNS ~-0.5 ns  (may fail, try optimization)

---

## Running your own program

1. Write RISC-V assembly (prog.s is an example)
2. Assemble to hex:
     riscv32-unknown-elf-gcc -march=rv32i -mabi=ilp32 \
       -nostdlib -Ttext 0x0 -o prog.elf prog.s
     riscv32-unknown-elf-objcopy -O verilog prog.elf imem.hex
3. Place imem.hex in the project directory
4. Simulate or synthesise — CPU reads imem.hex on startup
5. Watch debug_reg_x10 (a0 register) on the LEDs

Online toolchain (no install): https://godbolt.org
  - Set compiler to RISC-V rv32 gcc
  - Set flags: -march=rv32i -mabi=ilp32 -O0

---

## Supported instructions

R-type : ADD SUB AND OR XOR SLL SRL SRA SLT SLTU
I-arith: ADDI ANDI ORI XORI SLTI SLTIU SLLI SRLI SRAI
Loads  : LW LH LB LHU LBU
Stores : SW SH SB
Branches:BEQ BNE BLT BGE BLTU BGEU
Jumps  : JAL JALR
Upper  : LUI AUIPC

---

## Next steps after this works

1. Add pipeline registers between stages → 5-stage pipeline
2. Add forwarding unit (MUX on ALU inputs) → handle data hazards
3. Add hazard detection unit → stall on load-use hazard
4. Add branch predictor → reduce branch penalty
5. Add cache → faster memory access
