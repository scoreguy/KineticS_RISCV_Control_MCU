# ============================================================
# Sample RISC-V assembly program for the single-cycle CPU
# Tests: arithmetic, loop, memory, function call
#
# Compile to imem.hex:
#   riscv32-unknown-elf-gcc -march=rv32i -mabi=ilp32 \
#     -nostdlib -Ttext 0x0 -o prog.elf prog.s
#   riscv32-unknown-elf-objcopy -O verilog prog.elf imem.hex
#
# Or use the online assembler: https://riscvasm.lucasteske.dev/
# ============================================================

.section .text
.globl _start

_start:
    # --------------------------------------------------------
    # 1. Load some constants
    # --------------------------------------------------------
    addi x1, x0, 10          # x1 = 10
    addi x2, x0, 5           # x2 = 5

    # --------------------------------------------------------
    # 2. Arithmetic
    # --------------------------------------------------------
    add  x3, x1, x2           # x3 = 15
    sub  x4, x1, x2           # x4 = 5
    mul_approx:
    slli x5, x1, 2            # x5 = 40  (x1 * 4 via shift)
    srai x6, x5, 1            # x6 = 20  (arithmetic right shift)

    # --------------------------------------------------------
    # 3. Loop: sum 1..5 into x10  (expected: 15)
    # --------------------------------------------------------
    addi x10, x0, 0           # x10 = accumulator = 0
    addi x11, x0, 1           # x11 = counter = 1
    addi x12, x0, 5           # x12 = limit = 5

loop:
    add  x10, x10, x11        # acc += counter
    addi x11, x11, 1          # counter++
    ble_approx:
    blt  x12, x11, loop_done  # if limit < counter, exit
    beq  x0,  x0,  loop       # unconditional loop (BEQ x0,x0)

loop_done:
    # x10 should now be 15

    # --------------------------------------------------------
    # 4. Memory: store and reload
    # --------------------------------------------------------
    addi x20, x0, 200         # x20 = base address 200
    sw   x10, 0(x20)          # mem[200] = 15
    lw   x21, 0(x20)          # x21 = mem[200] = 15  (should match x10)

    # --------------------------------------------------------
    # 5. Function call via JAL
    # --------------------------------------------------------
    addi a0, x0, 7            # a0 (x10) = argument = 7
    jal  ra, double_it        # call double_it(7), ra = return addr

    # a0 should now be 14
    sw   a0, 4(x20)           # store result

    # --------------------------------------------------------
    # 6. Infinite loop (halt — CPU keeps running but PC stays)
    # --------------------------------------------------------
halt:
    beq  x0, x0, halt

# ============================================================
# Function: double_it
# Args  : a0 = input value
# Return: a0 = a0 * 2
# ============================================================
double_it:
    slli a0, a0, 1            # a0 = a0 << 1  (multiply by 2)
    jalr x0, ra, 0            # return (JALR x0, ra, 0)
