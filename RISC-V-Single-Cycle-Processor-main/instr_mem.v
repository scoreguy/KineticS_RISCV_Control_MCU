// ============================================================
// Module : instr_mem
// Desc   : Instruction memory (ROM).
//   - 256 words × 32 bits = 1 KB
//   - Asynchronous read (combinational — single-cycle CPU)
//   - Initialised from imem.hex via $readmemh
//   - FPGA: synthesises to a BRAM in read-only mode
//
// To generate imem.hex from a RISC-V assembly file:
//   riscv32-unknown-elf-as   prog.s -o prog.o
//   riscv32-unknown-elf-ld   prog.o -o prog.elf -Ttext 0
//   riscv32-unknown-elf-objcopy -O verilog prog.elf imem.hex
// ============================================================
`timescale 1ns/1ps

module instr_mem #(
    parameter DEPTH = 256                   // number of 32-bit words
)(
    input  wire [31:0] addr,               // byte address from PC
    output wire [31:0] instr              // 32-bit instruction word
);

    reg [31:0] mem [0:DEPTH-1];

    // Initialise from hex file if it exists
    // Each line in imem.hex is one 32-bit word in hex, e.g.: 00000013
    initial begin
        $readmemh("imem.hex", mem);
    end

    // Word-addressed read: addr[31:2] selects the word
    // addr[1:0] are always 00 for aligned instruction fetch
    assign instr = mem[addr[31:2]];

endmodule
