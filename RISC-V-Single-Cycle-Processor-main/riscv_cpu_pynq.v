// ============================================================
// Module : riscv_cpu  (top level) — PYNQ-Z2 edition
// Desc   : Complete RV32I Single-Cycle CPU
//
// Changes from Basys3 version:
//   - Removed debug_pc[31:0], debug_instr[31:0], debug_alu_result[31:0]
//     These 96 ports caused the [Place 30-58] "too many IO ports" error.
//   - debug_reg_x10 is now [3:0] (4 bits) to exactly match the 4 LEDs
//     on the PYNQ-Z2 (LD0-LD3). The upper 28 bits are unused on a board
//     with only 4 user LEDs.
//   - Part: xc7z020clg400-1 (Zynq 7020) — larger, faster than Basys3's
//     Artix-7 xc7a35t. Timing at 125 MHz is very comfortable.
//   - Clock: 125 MHz (H16) instead of 100 MHz (W5 on Basys3)
//
// IO:
//   clk           — 125 MHz from H16 (PL clock, independent of PS)
//   rst           — BTN0 (D19), active high
//   debug_reg_x10 — lower 4 bits of register a0 → LEDs LD0-LD3
// ============================================================
`timescale 1ns/1ps

module riscv_cpu (
    input  wire       clk,
    input  wire       rst,

    // 4-bit debug output → wired to LD0-LD3 on PYNQ-Z2
    // Shows lower nibble of register x10 (a0)
    // Program result: loop sum = 15 (0b1111 = all LEDs ON)
    //                 after double_it: 14 (0b1110 = LD0 off)
    output wire [3:0] debug_reg_x10
);

    // =========================================================
    // 1. PROGRAM COUNTER
    // =========================================================
    reg  [31:0] pc;
    wire [31:0] pc_plus4;
    wire [31:0] pc_next;
    wire [31:0] pc_branch_target;
    wire [31:0] pc_jump_target;

    assign pc_plus4 = pc + 32'd4;

    always @(posedge clk) begin
        if (rst)
            pc <= 32'b0;
        else
            pc <= pc_next;
    end

    // =========================================================
    // 2. INSTRUCTION FETCH
    // =========================================================
    wire [31:0] instr;

    instr_mem imem (
        .addr  (pc),
        .instr (instr)
    );

    // =========================================================
    // 3. INSTRUCTION DECODE
    // =========================================================
    wire [6:0] opcode  = instr[6:0];
    wire [4:0] rd_addr = instr[11:7];
    wire [2:0] funct3  = instr[14:12];
    wire [4:0] rs1_addr= instr[19:15];
    wire [4:0] rs2_addr= instr[24:20];
    wire [6:0] funct7  = instr[31:25];

    // =========================================================
    // 4. CONTROL UNIT
    // =========================================================
    wire        reg_write;
    wire        alu_src;
    wire [1:0]  alu_op;
    wire        mem_read;
    wire        mem_write;
    wire [1:0]  mem_to_reg;
    wire        branch;
    wire        jump;
    wire        lui;
    wire        auipc;

    control_unit ctrl (
        .opcode    (opcode),
        .reg_write (reg_write),
        .alu_src   (alu_src),
        .alu_op    (alu_op),
        .mem_read  (mem_read),
        .mem_write (mem_write),
        .mem_to_reg(mem_to_reg),
        .branch    (branch),
        .jump      (jump),
        .lui       (lui),
        .auipc     (auipc)
    );

    // =========================================================
    // 5. REGISTER FILE
    // =========================================================
    wire [31:0] rs1_data, rs2_data;
    wire [31:0] rd_data;

    register_file regfile (
        .clk       (clk),
        .rst       (rst),
        .reg_write (reg_write),
        .rd_addr   (rd_addr),
        .rd_data   (rd_data),
        .rs1_addr  (rs1_addr),
        .rs1_data  (rs1_data),
        .rs2_addr  (rs2_addr),
        .rs2_data  (rs2_data)
    );

    // =========================================================
    // 6. IMMEDIATE GENERATOR
    // =========================================================
    wire [31:0] imm_ext;

    imm_gen immgen (
        .instr   (instr),
        .imm_ext (imm_ext)
    );

    // =========================================================
    // 7. ALU CONTROL
    // =========================================================
    wire [3:0] alu_ctrl;

    alu_control alu_ctrl_unit (
        .alu_op  (alu_op),
        .funct3  (funct3),
        .funct7_5(funct7[5]),
        .alu_ctrl(alu_ctrl)
    );

    // =========================================================
    // 8. ALU
    // =========================================================
    wire [31:0] alu_a;
    wire [31:0] alu_b;
    wire [31:0] alu_result;
    wire        alu_zero;

    assign alu_a = auipc ? pc :
                   lui   ? 32'b0 :
                           rs1_data;

    assign alu_b = alu_src ? imm_ext : rs2_data;

    alu alu_inst (
        .a       (alu_a),
        .b       (alu_b),
        .alu_ctrl(alu_ctrl),
        .result  (alu_result),
        .zero    (alu_zero)
    );

    wire alu_negative = alu_result[31];
    wire alu_overflow = (alu_a[31] != alu_b[31]) && (alu_result[31] != alu_a[31]);
    wire alu_carry    = (rs1_data < rs2_data);

    // =========================================================
    // 9. BRANCH CONTROL
    // =========================================================
    wire take_branch;

    branch_control bctrl (
        .branch     (branch),
        .funct3     (funct3),
        .zero       (alu_zero),
        .negative   (alu_negative),
        .overflow   (alu_overflow),
        .carry      (alu_carry),
        .take_branch(take_branch)
    );

    // =========================================================
    // 10. PC TARGET
    // =========================================================
    assign pc_branch_target = pc + imm_ext;
    assign pc_jump_target   = (opcode == 7'b1100111) ?
                              {alu_result[31:1], 1'b0} :
                              pc_branch_target;

    assign pc_next = jump        ? pc_jump_target   :
                     take_branch ? pc_branch_target :
                                   pc_plus4;

    // =========================================================
    // 11. DATA MEMORY
    // =========================================================
    wire [31:0] mem_read_data;

    data_mem dmem (
        .clk        (clk),
        .mem_read   (mem_read),
        .mem_write  (mem_write),
        .funct3     (funct3),
        .addr       (alu_result),
        .write_data (rs2_data),
        .read_data  (mem_read_data)
    );

    // =========================================================
    // 12. WRITEBACK MUX
    // =========================================================
    assign rd_data = (mem_to_reg == 2'b00) ? alu_result    :
                     (mem_to_reg == 2'b01) ? mem_read_data :
                                             pc_plus4;

    // =========================================================
    // DEBUG OUTPUT — lower 4 bits of x10 (a0) → 4 LEDs
    // =========================================================
    assign debug_reg_x10 = regfile.regs[10][3:0];

endmodule
