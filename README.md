# Kinetic_S_RISCV_with_PID_core
The project explores a hybrid hardware–software architecture in which dedicated digital logic performs PID control computations, while a RISC-V processor handles high-level decision-making, system configuration, and communication. It incorporates multiple parallel PID loops, memory-mapped tuning of \(K_p\), \(K_i\), and \(K_d\), and peripheral interfaces such as UART, SPI, and I²C, alongside PWM outputs.

# ⚡ KINETIC-S
### Hardware-Accelerated PID Control with a RISC-V Soft-Core Processor

<p align="center">
  <strong>Deterministic Control. Parallel Computation. Open Hardware.</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Domain-Digital_Design-007ACC?style=for-the-badge" alt="Digital Design" />
  <img src="https://img.shields.io/badge/Architecture-RISC--V-6A5ACD?style=for-the-badge" alt="RISC-V" />
  <img src="https://img.shields.io/badge/Control-Hardware_PID-00A86B?style=for-the-badge" alt="Hardware PID" />
  <img src="https://img.shields.io/badge/Event-SEMIXTHON_2026-FF8C00?style=for-the-badge" alt="Semixthon 2026" />
</p>

---

## 🧠 Overview

**KINETIC-S** is a hybrid hardware–software control architecture that integrates a **RISC-V soft-core processor with dedicated hardware PID controllers** to enable parallel control computation for real-time embedded systems.

Traditional software-based PID controllers share processor resources with communication, sensor acquisition, and system-level tasks. This can introduce execution latency and timing variability into critical feedback loops.

KINETIC-S addresses this challenge by moving PID computation into dedicated digital logic while retaining the flexibility of a programmable RISC-V processor for system configuration, communication, and high-level decision-making.

> **The core idea:** Let hardware handle time-critical control computation while the processor handles system-level intelligence.

## ✨ Key Features

| Feature | Description |
|---|---|
| ⚙️ Hardware PID | Dedicated digital logic for PID control computation |
| 🧩 RISC-V Integration | Programmable soft-core processor for system management |
| 🔄 Parallel Control | Multiple PID instances for multi-axis control |
| 🎛️ Runtime Tuning | Memory-mapped access to \(K_p\), \(K_i\), and \(K_d\) |
| 🔌 Peripheral Interfaces | UART, SPI, and I²C connectivity |
| 📡 PWM Outputs | Control signals derived from PID computations |
| 🧪 RTL Simulation | Schematics, waveforms, and simulated controller outputs |

---

## 🏗️ System Architecture

KINETIC-S separates high-level processing from time-critical control computation using a bus-connected hardware architecture.

```text
                 ┌───────────────────────┐
                 │    RISC-V Soft Core   │
                 │                       │
                 │ System Control        │
                 │ Configuration         │
                 │ PID Parameter Updates  │
                 └───────────┬───────────┘
                             │
                       AXI Interconnect
                             │
             ┌───────────────┴───────────────┐
             │                               │
     ┌───────▼────────┐              ┌───────▼────────┐
     │  Hardware PID  │              │   Peripherals  │
     │   Controller   │              │                │
     ├────────────────┤              │ UART / SPI     │
     │ PID Loop 1     │              │ I²C / ADC      │
     │ PID Loop 2     │              └────────────────┘
     │ PID Loop 3     │
     │ PID Loop 4     │
     └───────┬────────┘
             │
        PWM Outputs
             │
             ▼
       Controlled Plant
```

*Conceptual representation of the architecture described in the project presentation. The exact bus topology and peripheral connections should be verified against the RTL.*

### 1. Processing Layer — RISC-V

The processor handles operations that benefit from programmability:

- High-level decision-making and system configuration.
- Communication and peripheral management.
- Updating PID gains through memory-mapped registers.
- Coordination of the hardware control subsystem.

### 2. Control Layer — Hardware PID

Dedicated digital logic executes the control computations