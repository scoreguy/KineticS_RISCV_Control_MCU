# Shared MAC Core

## Scope

This directory contains the shared-MAC compute block for the larger KINETIC-S RISC-V MCU project: a parameterized multiply-accumulate core, a local register and streaming wrapper, and self-checking testbenches. The MAC has no PID-specific state: it performs arithmetic commands while the caller owns the PID history, error calculation, scheduling, final sum, and actuator policy.

The MAC-based PID simulation is the current control-system milestone. The RISC-V processor, system peripheral fabric, and physical sensor/actuator connections are planned integrations around this block, not part of this standalone core.

The PID and hinged propeller-arm examples in this project are simulations. They do not represent a physical motor/IMU test or a completed RISC-V, AXI-Lite, DMA, UART, SPI, or PWM integration.

## Why use a MAC instead of replicated PID arithmetic

A parallel gate-level PID design can instantiate separate multipliers and adders for P, I, and D, and replicate those datapaths for every axis. This can compute terms concurrently and minimize update latency, but the amount of arithmetic hardware and routing grows with the number of terms and axes.

The shared MAC reuses one multiplier and accumulator. The caller issues commands for each product in sequence and stores the remaining PID state. This reduces duplicated arithmetic hardware while trading away parallel throughput. A MAC is still built from digital logic; it is a reusable datapath, not a replacement for all of the logic in a PID controller.

For a software comparison, a basic CPU without a fused MAC instruction may need several instructions to prepare values, multiply, add to the accumulator, and write back. Around six steps is an illustrative sequence, not a measured or universal CPU instruction count. One command to this core represents `accumulator + a * b`. The actual core accepts that command on a clock edge and commits the result on the next edge. The full PID update is not a one-clock operation.

In the supplied bus-driven PID test, three MAC calls are used per sample for the P, I, and D products. The logged 60 cycles per axis sample include register writes, status polling, and result reads in the testbench schedule; they are not 60 cycles of arithmetic latency inside the MAC.

## Datapath behavior

For a multiply-accumulate command, the core performs:

```text
acc_next = acc + quantize(a * b)
```

`quantize` applies the optional right shift and rounding behavior. The optional saturation mode clamps the final extended sum; without saturation, the low accumulator-width bits are retained.

The core also supports clear and load operations. Operand width and accumulator width are parameters. Signed mode sign-extends operands and the accumulator; unsigned mode zero-extends them. There is no implied physical unit or fixed-point Q format in the core.

| Command | `cmd_op` | Behavior |
|---|---:|---|
| MAC | 0 | Add the shifted product to the accumulator |
| Clear | 1 | Set the accumulator to zero |
| Load | 2 | Load `load_value` into the accumulator |
| Reserved | 3 | Core-level no-op; the register wrapper rejects unsupported command values |

### Command timing

- A command is accepted on a rising edge when `cmd_valid && cmd_ready` is true.
- `cmd_ready` is high when enabled, out of reset, and not busy.
- The core latches the command and product at acceptance, then commits the result and pulses `done` on the next rising edge.
- The initiation interval is two clocks: the following command can be accepted on the next edge after completion.
- Reset is synchronous and active high. It clears the accumulator and aborts pending work.

This timing describes one core command. A register-driven PID sample contains multiple commands plus wrapper transactions and caller-side state work.

## Register wrapper

`mac_regs.sv` provides a local 32-bit full-word valid/ready bus. It is not an AXI-Lite slave: it has no independent AXI read/write channels, response backpressure, or byte strobes.

| Byte offset | Register | Access | Meaning |
|---|---|---|---|
| `0x00` | A | Read/write | Operand A bit pattern |
| `0x04` | B | Read/write | Operand B bit pattern |
| `0x08` | LOAD | Read/write | Value supplied to the load command |
| `0x0C` | MODE | Read/write | bit 0 signed; bit 1 saturation; bit 2 rounding; bits 10:3 shift amount |
| `0x10` | COMMAND | Write | `0` MAC, `1` clear, `2` load; other values return an error |
| `0x14` | STATUS | Read/write-one-to-clear | bit 0 busy; bit 1 done; write bit 1 to clear sticky done |
| `0x18` | RESULT | Read | Committed accumulator value |

Bus transactions complete on a rising edge with `bus_valid && bus_ready`. A command write waits while the core is busy. Stream commands have priority over competing bus command writes; the wrapper has no command or result FIFO. The stream interface is not AXI-Stream.

## PID integration model

The testbench acts as a software-like command scheduler:

1. It stores each axis's error and delayed P/I/D state outside the MAC.
2. It writes operands, mode, and command values through `mac_regs`.
3. It waits for the done status and reads the committed result.
4. It updates the PID state and combines/clamps the final control output outside the core.
5. It advances the simplified plant model and uses its output as the next feedback sample.

This arrangement demonstrates resource sharing and arithmetic equivalence. It does not place a CPU or a PID state machine inside the MAC.

## Basic MAC example

The supplied basic testbench checks eight clear, load, and multiply-accumulate operations:

| Operation | Expected accumulator |
|---|---:|
| Clear | 0 |
| `0 + 3 * 4` | 12 |
| `12 + 2 * 5` | 22 |
| `22 + (-2) * 3` | 16 |
| Load 100 | 100 |
| `100 + 7 * 6` | 142 |
| Clear | 0 |
| `0 + 7 * 6` | 42 |

The supplied simulation output reports `PASS BASIC MAC: all 8 steps passed` at 472 ns.

## Verification results

The existing regression report records the following checks:

| Check | Recorded result |
|---|---|
| Original PID RTL capture | 88,000 axis samples |
| Independent Python PID model | 88,000 original RTL outputs matched |
| Shared-MAC PID execution | 88,000 axis samples matched the original RTL |
| MAC configurations | 32/32, 8/24, and 16/64 operand/accumulator widths |
| Arithmetic model vectors | 9,106 vectors per configuration |
| Fake-CPU testbench schedule | 60 cycles per axis; 240 cycles per four-axis frame |
| Register and stream wrapper | Arbitration, errors, status, held requests, and reset checks passed |

The cycle counts are simulation schedules, not FPGA timing results. No verified FPGA area, power, maximum clock frequency, or post-route timing report is included.

## Media

Store the MAC screenshots in the repository-level `media/` directory, or adjust these paths to match your names:

![Basic MAC command and result waveform](../media/mac-core-waveform.png)

![MAC core logic schematic](../media/mac-core-schematic.png)

![Basic MAC testbench sequence](../media/mac-core-testbench.png)

## Run the regression

Install Python 3 and Icarus Verilog (`iverilog` and `vvp`), then run from this directory:

```sh
python scripts/run.py
```

The runner generates the vectors, compiles the RTL, runs the simulations, and checks pass/fail results. The project README describes the optional Windows direct-backend invocation when the standard Icarus launcher is unavailable.

## Main files

| Path | Purpose |
|---|---|
| `rtl/mac_core.sv` | Parameterized arithmetic core |
| `rtl/mac_regs.sv` | Register and streaming command wrapper |
| `tb/tb_mac_basic.sv` | Eight-operation educational MAC sequence |
| `tb/tb_mac.sv` | Parameterized arithmetic and handshake tests |
| `tb/tb_regs.sv` | Register, stream, status, arbitration, and reset tests |
| `tb/tb_pid_mac.sv` | Software-like scheduler and shared-MAC PID comparison |
| `docs/design_review.md` | Arithmetic compatibility, assumptions, and limitations |
