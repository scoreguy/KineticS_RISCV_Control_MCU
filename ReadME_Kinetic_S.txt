
Kinetic S - Planned RISC-V MCU with Multi-Axis Hardware PID Control

Project Design and Implementation by : Azhar Jawed ( email - azharjawed23773@gmail.comm)

-------------
## Overview
-------------

Kinetic S is a planned custom embedded control architecture centered around a single-cycle RISC-V MCU with dedicated hardware PID accelerators. The long-term goal is a programmable real-time control platform for drones, robotics systems, CNC stages, and balancing applications.

At the current development stage, the hardware PID control block and UART communication subsystem have been completed and verified. 
The RISC-V MCU integration is the next planned milestone. Updated Code will be shared soon . 

The architecture combines future software programmability through the MCU with deterministic hardware control loops, allowing fast response times while keeping tuning and telemetry flexible through UART communication.

The core design objective is to offload only the computationally repetitive PID output calculations from the MCU rather than running the full control loop purely in software. By moving PID math into dedicated hardware blocks, the MCU remains free for navigation logic, communication, sensor fusion, safety handling, and higher-level decision making while control outputs are generated with lower latency and deterministic timing.

## Core Architecture

* Single-cycle RISC-V MCU for register management, command handling, and supervisory control.
* There are 4 PID controller output lines , that compute the total offset and feed it back to the mcu , while also generating corresponding pwm output to counter it.
* PWM Generators for actuator / motor drive outputs.
* UART Interface for runtime tuning, telemetry, and command exchange.
* Modular RTL implementation with synthesis and simulation verification.

## How the Control System Works

Each control loop receives:

1. Setpoint — desired target state (example: level attitude = 0° roll/pitch/yaw).
2. Feedback — measured current state from sensors / external inputs.
3. Error = Setpoint − Feedback.

For each line , as setpoint and real time value is fed into the registers:

* P (Proportional) reacts to current error.
* I (Integral) removes steady-state bias or drift.
* D (Derivative) damps oscillation and predicts motion trend.

=============================================
## Testbench Scenario — Object Stabilization
=============================================

The primary verification focus of Kinetic S is the closed-loop testbench rather than only the hardware blocks. The testbench emulates an unstable object that must be driven back to equilibrium by four control lines running in parallel. Each controller computes simultaneously every clock cycle, similar to dedicated MAC-style hardware accelerators operating concurrently.

### Parallel Control Channels

* Roll PID computes corrective torque for roll stabilization.
* Pitch PID computes corrective torque for pitch stabilization.
* Yaw PID computes corrective torque for heading stabilization.
* Z PD computes vertical correction / thrust adjustment.

Each line generates a control magnitude that is translated into PWM outputs for actuators. Because the channels are independent hardware datapaths, all four axes update in parallel rather than sequentially.


The verification testbench models an initially unstable object / platform.

### Initial Conditions

Simulation begins with significant offsets from equilibrium, representing a disturbed platform:

* t=75,000: roll = 300, pitch = -180, yaw = 430, z = -210

* Subsequent samples show gradual convergence toward zero.

* Z-axis target is driven from approximately -210 upward to the desired value of 0.

* Roll offset present

* Pitch offset present

* Yaw offset present

* Z-axis height disturbance present

### Desired Targets

* Roll = 0
* Pitch = 0
* Yaw = 0
* Z = 0 (from an initial negative disturbance near -210)

### Closed-Loop Behavior

At each simulated clock cycle:

1. Controllers compute corrective outputs.
2. PWM outputs represent actuator commands.
3. Testbench updates feedback values to emulate physical response.
4. Disturbances may be injected to test robustness.

### Expected Result

Observed waveform / console logs show monotonic correction over time. Example progression:

* t=75,000 → roll 281, pitch -168, yaw 419, z -204
* t=175,000 → roll 162, pitch -85, yaw 239, z -104
* t=295,000 → roll 87, pitch -36, yaw 123, z -44

All axes trend toward zero while PWM outputs continuously adapt to reduce the remaining error.

Over time:

* Roll converges toward zero.
* Pitch converges toward zero.
* Yaw converges toward zero.
* Z stabilizes at target height.
* Oscillation reduces as derivative terms damp motion.

### UART Register Connectivity

UART is connected to internal configuration and telemetry registers. Through UART, an external host can:

* Write tuned Kp / Ki / Kd gains for each PID line.
* Update setpoints for roll, pitch, yaw, and Z.
* Read controller outputs and internal tuned values.
* Fetch live telemetry or debug values without recompiling the design.

## UART Runtime Control

UART commands can be used to:

* Update Kp / Ki / Kd gains live.
* Change setpoints.
* Read controller outputs.
* Observe telemetry values.

This enables tuning without recompiling RTL.

## Verification Coverage

The RTL testbench validates:

* UART transmit / receive behavior.
* Register writes and reads.
* PID arithmetic datapaths.
* PWM generation.
* Multi-axis simultaneous closed-loop correction.
* Reset behavior and startup conditions.

## Applications

* Self-balancing platforms
* Robotic manipulators
* CNC axis control
* Autonomous motion systems
* Cost cutting on Motor Control / Parameter based control system hardware.

## Future Expansion — RISC-V Integration

A lightweight single-cycle RISC-V core can be added as a supervisory controller to manage higher-level tasks such as autonomous logic, communication scheduling, trajectory planning, safety states, and advanced gain scheduling while the hardware PID engines continue deterministic real-time control.

## Project Summary

Kinetic S demonstrates a hybrid embedded architecture where a lightweight MCU coordinates multiple dedicated hardware control engines, achieving deterministic real-time control with configurable software-level supervision.
