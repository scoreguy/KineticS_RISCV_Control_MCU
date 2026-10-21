# KINETIC-S standalone general MAC

One reusable MAC datapath, a local register/stream wrapper, and self-checking tests that reproduce the original four-axis PID arithmetic. RISC-V, AXI-Lite bridging, DMA, UART, SPI and PWM integration are deferred.

## Files to use

| File | Purpose |
|---|---|
| `rtl/mac_core.sv` | Parameterized general MAC; no PID-specific state |
| `rtl/mac_regs.sv` | 32-bit register interface and streaming command arbitration |
| `tb/tb_mac.sv` | Independent Python-generated arithmetic vectors and core handshake tests |
| `tb/tb_pid_mac.sv` | Fake CPU, four sets of software PID state, one shared MAC; golden and closed-loop checks |
| `tb/tb_regs.sv` | Bus/stream/status/reset tests |
| `tb/tb_golden.sv` | Capture outputs from the unchanged original PID |
| `reference/` | Unchanged supplied/recovered source files; not part of new synthesis |
| `tb/legacy_top.sv` | Recovered wrapper for the unchanged original monitor-only testbench |
| `scripts/run.py` | Generate vectors, compile, simulate and check; standard library Python |
| `docs/design_review.md` | Original arithmetic, findings, provenance and scope |
| `docs/test_log.txt` | Actual successful regression commands and outputs |
| `golden/closed_loop.csv` | Feedback plus original/MAC outputs for the original plant case |
| `docs/closed_loop.png` | Plot of that simulated sample sequence |
| `scripts/synth.tcl` | Optional Vivado synthesis; not successfully run on this host |

```text
Future CPU / local bus ----> mac_regs ----> mac_core (ONE multiplier + accumulator)
Future DMA command stream ------^              |
                              result/status <--+

PID testbench: 4 sets of P/I/D/error state -> sequential bus commands -> same MAC
```

## Run

Install Python 3 and Icarus Verilog (`iverilog`, `vvp` on PATH), then from this directory:

```sh
python scripts/run.py
```

The installed Windows Icarus launcher crashed on this host, so the **successfully executed** regression used its compiler backend directly:

```powershell
$env:IVL_DIR = 'D:/iverilog/lib/ivl'
python scripts/run.py --ivl-direct
```

This option is Windows-specific and supports these self-contained sources (no Verilog includes/macros). It writes a compiler configuration and concatenates source text with location directives, invokes `ivl.exe`, then `vvp`. Every nonzero exit still fails the regression; compiler crashes are never ignored. A working normal Icarus installation should use the first command. No test requires proprietary simulation tools. Optional plotting uses `python scripts/plot.py` with matplotlib installed.

Actual final results:

```text
PASS original RTL capture: 88000 axis samples
PASS independent Python PID model: 88000 original RTL outputs
PASS MAC W=32 AW=32: 9106 model vectors, disable/latching/reset
PASS MAC W=8 AW=24: 9106 model vectors, disable/latching/reset
PASS MAC W=16 AW=64: 9106 model vectors, disable/latching/reset
PASS shared-MAC PID: 88000 axis samples match original RTL
MEASURED fake-CPU schedule: 60 cycles/axis, 240 cycles/4-axis frame
PASS register/stream arbitration, errors, sticky status, held requests, reset
PASS ALL REGRESSIONS
```

The old testbench additionally ran for 500 clocks; it prints values but has no assertions. The tests above supply actual pass/fail checks. `golden/original.txt` is generated from original RTL, not assigned from the Python model. The Python and RTL outputs are checked before MAC comparison. Seeds are fixed for repeatability.

## Core command contract

New RTL reset is **synchronous, active high**. Hold it across a rising clock edge. Reset zeroes the accumulator and aborts pending work. The preserved reference PID has asynchronous reset.

- A command is accepted only on a rising edge with `cmd_valid && cmd_ready`.
- Hold all command fields stable until acceptance. `cmd_ready = enable && !busy && !rst`.
- `enable` gates acceptance only. Accepted work completes even if enable later falls.
- Acceptance latches operation, product and controls and sets busy. On the next rising edge, the result commits, busy clears and done pulses for one cycle. Next acceptance is the following edge: initiation interval two clocks.
- `cmd_op`: 0 MAC; 1 clear; 2 load; 3 reserved no-op with normal done. Bus COMMAND rejects 3.
- `a,b` have `OPERAND_W` bits, `load_value/acc` have `ACC_W` bits. Both parameters must be positive. Tested configurations are listed above. The wrapper is intentionally fixed at 32/32; widening it requires expanding the register map.
- Signed mode sign-extends both operands and accumulator; unsigned mode zero-extends them. Product is computed at full width before shifting. Modes reinterpret the existing accumulator bits; changing modes does not convert their representation.
- MAC: `acc = acc + quantize(a*b)`. `shift` is an unsigned 8-bit right-shift count. Without rounding, signed negative values round down (arithmetic shift); unsigned values use the equivalent logical shift.
- With rounding enabled and `0 < shift < EW`, add `2^(shift-1)` before shifting: nearest, ties toward positive infinity. `EW=max(2*(OPERAND_W+1),ACC_W)+2`. For shift >= EW, rounding bias is suppressed and arithmetic shift produces 0 or -1. Shift 0 applies no rounding.
- Saturation clamps the final extended sum to the selected signed or unsigned accumulator range. Otherwise low ACC_W bits are retained. Clear/load ignore arithmetic modes. PID's special +/-100000 clamp belongs to software/testbench, not the generic core.

## Local register interface

Transactions complete at a rising edge with `bus_valid && bus_ready`. Hold address/write/data stable until then. Reads are combinational and must be sampled at that edge. This is a full-word, single-beat interface with **no byte strobes and no AXI channels**. `bus_error` is meaningful on an accepted transaction. Invalid addresses, misalignment, writes to RESULT and invalid COMMAND values complete with error and no register side effect.

| Byte offset | Name | Access | Meaning |
|---|---|---|---|
| 0x00 | A | RW | Operand A bit pattern |
| 0x04 | B | RW | Operand B bit pattern |
| 0x08 | LOAD | RW | Value used by load command |
| 0x0C | MODE | RW | bit 0 signed; bit 1 saturation; bit 2 rounding; bits 10:3 shift; others ignored |
| 0x10 | COMMAND | W | 0 MAC, 1 clear, 2 load; all other values error. Read returns 0 |
| 0x14 | STATUS | R/W1C | bit 0 busy; bit 1 done. Write bit 1 to clear done; other write bits ignored |
| 0x18 | RESULT | R | Committed accumulator; remains old while busy |

Reset sets MODE=1 (signed), other registers zero. Operand/mode writes while busy affect only later commands. A COMMAND write stalls while busy or when a stream command has priority. Its acceptance clears prior done. Completion is visible immediately through the done pulse and retained in sticky state. A coincident completion wins over software clearing done; a newly accepted command clears old completion state. Do not use done to identify individual jobs from multiple unsynchronized masters.

Example: write LOAD, COMMAND=2, poll STATUS bit 1; write A/B/MODE, COMMAND=0, poll STATUS bit 1, read RESULT. Clear is COMMAND=1. PID testbench implements this sequence in reusable bus tasks.

## Stream interface and ownership

`stream_valid/stream_ready` carry the same core operation and 32-bit A/B/load fields. `stream_mode` has the same 11-bit layout as MODE. Streaming wins over a competing bus COMMAND; other register accesses can proceed. Sustained streaming can starve bus commands. Streaming does not modify the A/B/LOAD/MODE register bank.

There is one shared accumulator and no command FIFO, result FIFO, tag or result-ready input. `result` is the committed accumulator; `done` is its update pulse. A DMA consumer must sample/read the result before another completed command overwrites it, or pause submissions. Software and DMA need an external ownership/arbitration policy. This is streaming-friendly command input, **not AXI-Stream**.

## PID compatibility and timing

The original has a wrapped 16-bit error, delayed output, a two-sample integral recurrence, arithmetic shifts and wrapped internal sum before +/-100000 clamping. All are preserved. The fake CPU does three products through the MAC and retains P/I/D/error state in testbench arrays. It performs final addition/clamp and state management outside the accelerator, as future software will. The original gains are signed integers, not a documented Q-format.

The original 500-sample toy plant is checked at logical update boundaries. It settles to nonzero quantization residuals (roll/yaw 31, pitch/z 16 in this case); that is original behavior, not exact zero-error convergence. The plot demonstrates equality of two implementations, not proof of physical control stability.

| Schedule | Clocks | Time at assumed 125 MHz | Theoretical throughput |
|---|---:|---:|---:|
| One axis via tested register tasks | 60 | 480 ns | 2.0833 million axis updates/s |
| Four axes sequentially | 240 | 1.92 us | 520,833 four-axis frames/s |
| Original four parallel PID blocks, steady state | 1/frame | 8 ns | 125 million frames/s |

These are architectural cycle counts, **not achieved FPGA performance**. The original has an extra sample of output delay. The shared version trades throughput for one arithmetic resource; it does not preserve physical clock-for-clock output timing. The fake CPU's arithmetic/state calculations consume no extra simulated CPU cycles. Real firmware, instruction execution, bus bridges, DMA arbitration and sampling overhead will lower throughput. A single MAC is sufficient only for an application whose full timing budget fits; no required plant control rate was supplied. Synthesis/place-and-route timing and FPGA resource use are not verified.

## Proposed system map (future, not implemented)

| Region | Proposed base | Size |
|---|---:|---:|
| Boot ROM | 0x00000000 | 64 KiB |
| RAM | 0x10000000 | 64 KiB |
| MAC | 0x40000000 | 4 KiB |
| Four PWM duty registers/peripheral | 0x40001000 | 4 KiB |
| UART | 0x40002000 | 4 KiB |
| SPI | 0x40003000 | 4 KiB |
| DMA | 0x40004000 | 4 KiB |
| Later I2C / ADC / interrupts | 0x40005000 / 0x40006000 / 0x40007000 | 4 KiB each |

Use an address decoder to convert MAC addresses to the local offsets above. An AXI-Lite bridge can preserve the slide architecture. Other peripherals' register maps remain a later design task. Keep PWM separate, with CPU/DMA writing duty and direction after a completed update. Compile only `rtl/mac_core.sv` and `rtl/mac_regs.sv` for the new synthesizable MAC; `tb/` and `reference/` are verification material.

Optional synthesis in a configured Vivado shell: `vivado -mode batch -source scripts/synth.tcl`. This targets xc7z020clg400-1 with an 8 ns clock. Out-of-context synthesis is not routed timing closure or board validation.
