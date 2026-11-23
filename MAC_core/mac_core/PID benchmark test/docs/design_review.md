# Standalone MAC conversion review

## Scope and provenance

The user's request is the standalone general MAC and PID testbenches, with RISC-V/bus integration later. The supplied Markdown is a wider project plan (including a Stage-0-only instruction); this delivery completes the requested standalone work without attempting CPU, UART, SPI, DMA or pipeline implementation.

`pid_3axis.zip` contains `new_sim.v`, an XPR, ILA IP and generated implementation/simulation products. It does **not** contain the user PID/PWM/top RTL. The XPR references `../../project_1/project_1.srcs/sources_1/new/{pid_main.v,pwm.v,top_mod.v}`. These files were available at `C:/Users/AZHAR/project_1/project_1.srcs/sources_1/new/` and were copied unchanged into `reference/`. The old xvlog log confirms these same source paths. This proves provenance of the inspected local files, not that their current contents are identical to the historical slide build. SHA-256 hashes are recorded separately.

The original `new_sim.v` is copied unchanged from the ZIP. `tb/legacy_top.sv` recovers the commented `top_4pid_pwm` definition in the local top file and removes redundant declarations of output wires. This is a simulation wrapper repair; PID arithmetic remains unchanged. The original active `top_final` and the archive testbench do not elaborate together directly because the testbench instantiates `top_4pid_pwm`.

## Architecture and slide comparison

Slides 6 and 9 show RISC-V, AXI/AXI-Lite, four parallel PID instances, four separate PWM modules and separate communications. The provided testbench models four axes even though the archive is named `pid_3axis`. Its hierarchy is `tb_top_4pid -> top_4pid_pwm -> 4 x PID + 4 x pwm`.

The current active local top is instead `top_final -> 4 x PID + 4 x pwm + ila_0`, with fixed gains, zero setpoints and a synthesized feedback toy model. No CPU, bus or gain register interface is present in this top. Reset is tied low. The slide behavior is a simulation example, not a physical-plant stability or timing guarantee. The testbench uses a 100 MHz clock, whereas this task targets 125 MHz. The new testbenches use an 8 ns clock.

New hierarchy: `mac_regs -> mac_core` (one multiplication expression). The testbench owns per-axis state and sequences the single core. PWM remains a separate peripheral. A logical multiplier can map onto multiple FPGA DSP slices; this delivery does not claim one DSP slice.

## Ranked findings

1. **High: reset absent in active top.** `reference/top_mod.v` ties reset low. PID state has no initialization and becomes unknown in RTL simulation. Do not use this top for board bring-up as-is.
2. **High: integral recurrence is delayed.** `reference/pid_main.v:45,67` implement two interleaved accumulations, not `I[n]=I[n-1]+...`. Preserved for exact compatibility.
3. **High: internal overflow precedes clamping.** `pid_main.v:45,55` wrap at 32 bits. Clamping only the output at lines 57-62 is not anti-windup; sustained input can wrap the integral and reverse the clamped output. Long-run tests cover this.
4. **High: error narrowing.** `pid_main.v:18-19` wraps the full signed 16-bit input difference back to 16 bits. For example 32767 - (-32768) becomes -1. Preserved.
5. **Medium: output timing differs from the Markdown pseudocode.** Nonblocking assignments at lines 40,45,50 and the sum at line 55 make output depend on the previous terms. The MAC fake CPU preserves this extra sample delay.
6. **Medium: stale simulation top and no assertions.** Archive `new_sim.v` expects a now-commented top, only prints feedback, and has no pass/fail criteria. We recover the wrapper and add independent self-checking tests.
7. **Medium: plant sign/damping.** The testbench subtracts the control output despite error being setpoint minus feedback, while adding damping `-fb/16`. Convergence in this model does not establish correct actuator polarity. Ki=0 in the original demo does not exercise integral behavior.
8. **Low: unused inputs.** `Ts` and `Gd` at PID lines 4-5 do not affect arithmetic. They are not sampling-period or filter controls in this implementation.
9. **Separate PWM issue, unchanged:** the slow-clock divider is unused by the active PWM logic. `counter1 + 1` in the comparison is widened by the unsized literal, so the wrap edge compares 256 rather than 0. No PWM fixes are included in this MAC deliverable.

No CPU RTL was supplied for this scope. The Markdown's suspected CPU bugs were not treated as verified findings and no CPU audit is claimed.

## Exact original numerical contract

All inputs are signed integer bit patterns: gains 8 bits; setpoint and feedback 16 bits. There is no declared uniform Q-format. The integral product is arithmetic-shifted by 4 (division by 16, floor for negatives), the derivative product by 2 (division by 4). There is no rounding to nearest in the legacy path.

With wrapW denoting two's-complement W-bit wrap:

```
e[n]   = wrap16(sp[n] - fb[n])
P[n]   = wrap32(Kp[n] * e[n])
I[n]   = wrap32(I[n-2] + (wrap32(Ki[n] * e[n]) >>> 4))
D[n]   = wrap32(Kd[n] * (sign_extend32(e[n]) - sign_extend32(e[n-1]))) >>> 2
out[n] = clamp(wrap32(P[n-1] + I[n-1] + D[n-1]), -100000, 100000)
```

The derivative subtraction is evaluated in the 32-bit expression context; it is not a 16-bit wrapped difference. All historical terms reset to zero. The unmodified PID uses asynchronous active-high reset; the new standalone core uses synchronous active-high reset. Comparisons are made at completed sample boundaries after reset, not at asynchronous edges.

The Python model was checked against captured output from unmodified PID RTL before comparing the MAC. The fake CPU performs three MAC products, loading either zero or the appropriate previous integral. It stores delayed P/I/D and error per axis, and performs final wrapped addition/clamp in the testbench (future software). Gains can change each sample, as in the reference RTL. No PID registers or recurrence exist inside `rtl/`.

Changing to a conventional one-state integral, widening the error, adding anti-windup, removing the output delay or reversing the plant sign changes outputs. Those are future explicit algorithm revisions, not silent fixes in this delivery.

## Verification and limits

The regression captures 88,000 original RTL outputs (22,000 frames x 4 axes) and compares them against the independent Python model and shared-MAC execution. Cases include the original disturbed plant, zero input, extreme signed subtraction, sign changes, independent randomized gains/inputs, long saturation through integral overflow and reset mid-run.

The first 500 active frames also update a plant inside the MAC test using MAC-derived historical outputs. Its feedback and outputs must equal the baseline trajectory. `golden/closed_loop.csv` records both outputs, not just a visually similar curve. Timing is rescaled to logical sample boundaries: a faster-running plant on every physical MAC clock would be a different experiment.

Three core configurations (32/32, 8/24, 16/64 operand/accumulator bits) each run 9,106 Python-model vectors covering signed/unsigned, shifts, rounding, saturation/wrap, clear/load/no-op, directed edges, random sequences, dot products and FIR. Handshake tests check command latching, enable, busy, done and reset abort. Register tests cover arbitration, held requests, errors and completion status.

The installed Icarus launcher crashed after invoking its compiler; the direct backend path in `scripts/run.py --ivl-direct` compiles and simulates successfully without ignoring nonzero exits. The normal Icarus path is retained for ordinary installations. An alternate XSim attempt failed in generated C compilation; a Vivado synthesis launch failed in environment setup. Neither counts as synthesis, timing closure or independent simulator validation. There is no measured FPGA Fmax/resource report. Use the included optional Vivado script in a configured Vivado shell.

## Future integration

Use the simple local valid/ready interface now, then an AXI-Lite bridge around it. AXI-Lite independent read/write channels and response backpressure must be implemented by that bridge; this module is not an AXI-Lite slave. Preserve the local register offsets when adding a system address decoder. DMA must arbitrate ownership of the single accumulator, hold commands until accepted and consume results before issuing work that overwrites them. No atomic PID transaction or software locking is implemented here.

Recommended commit split: (1) `test: capture original PID semantics and regression vectors`; (2) `feat: add standalone shared MAC and register/stream verification`.
