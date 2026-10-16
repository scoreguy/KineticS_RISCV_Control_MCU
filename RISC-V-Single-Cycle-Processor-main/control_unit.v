// ============================================================
// Module : control_unit
// Desc   : Main control unit. Decodes the 7-bit opcode and
//          drives all datapath control signals.
//
// Control signals:
//   reg_write   — write result to rd in register file
//   alu_src     — 0 = rs2_data, 1 = immediate (B operand)
//   alu_op[1:0] — tells alu_control what class of operation
//   mem_read    — read from data memory (LW,LH,LB,LHU,LBU)
//   mem_write   — write to data memory (SW,SH,SB)
//   mem_to_reg  — WB MUX: 0=ALU result, 1=mem data, 2=PC+4
//   branch      — instruction is a branch (BEQ,BNE,BLT,etc.)
//   jump        — unconditional jump (JAL / JALR)
//   lui         — LUI instruction (bypass ALU A input)
//   auipc       — AUIPC instruction (A input = PC)
// ============================================================
`timescale 1ns/1ps

module control_unit (
    input  wire [6:0] opcode,

    output reg        reg_write,
    output reg        alu_src,
    output reg [1:0]  alu_op,
    output reg        mem_read,
    output reg        mem_write,
    output reg [1:0]  mem_to_reg,  // 00=ALU, 01=MEM, 10=PC+4
    output reg        branch,
    output reg        jump,
    output reg        lui,
    output reg        auipc
);

    // RV32I opcode map
    localparam OP_R      = 7'b0110011;   // R-type:  ADD SUB AND OR XOR SLL SRL SRA SLT SLTU
    localparam OP_I_ARITH= 7'b0010011;   // I-arith: ADDI ANDI ORI XORI SLTI SLTIU SLLI SRLI SRAI
    localparam OP_LOAD   = 7'b0000011;   // Loads:   LW LH LB LHU LBU
    localparam OP_STORE  = 7'b0100011;   // Stores:  SW SH SB
    localparam OP_BRANCH = 7'b1100011;   // Branches:BEQ BNE BLT BGE BLTU BGEU
    localparam OP_JAL    = 7'b1101111;   // JAL
    localparam OP_JALR   = 7'b1100111;   // JALR
    localparam OP_LUI    = 7'b0110111;   // LUI
    localparam OP_AUIPC  = 7'b0010111;   // AUIPC

    always @(*) begin
        // Safe defaults — prevents latches
        reg_write  = 1'b0;
        alu_src    = 1'b0;
        alu_op     = 2'b00;
        mem_read   = 1'b0;
        mem_write  = 1'b0;
        mem_to_reg = 2'b00;
        branch     = 1'b0;
        jump       = 1'b0;
        lui        = 1'b0;
        auipc      = 1'b0;

        case (opcode)
            OP_R: begin
                reg_write  = 1'b1;
                alu_src    = 1'b0;   // B = rs2
                alu_op     = 2'b10;  // use funct3/funct7
                mem_to_reg = 2'b00;
            end

            OP_I_ARITH: begin
                reg_write  = 1'b1;
                alu_src    = 1'b1;   // B = sign-extended immediate
                alu_op     = 2'b10;
                mem_to_reg = 2'b00;
            end

            OP_LOAD: begin
                reg_write  = 1'b1;
                alu_src    = 1'b1;   // address = rs1 + imm
                alu_op     = 2'b00;  // ADD
                mem_read   = 1'b1;
                mem_to_reg = 2'b01;  // WB ← mem data
            end

            OP_STORE: begin
                reg_write  = 1'b0;
                alu_src    = 1'b1;   // address = rs1 + imm
                alu_op     = 2'b00;  // ADD
                mem_write  = 1'b1;
            end

            OP_BRANCH: begin
                reg_write  = 1'b0;
                alu_src    = 1'b0;   // compare rs1 and rs2
                alu_op     = 2'b01;  // SUB (check zero/sign)
                branch     = 1'b1;
            end

            OP_JAL: begin
                reg_write  = 1'b1;
                alu_op     = 2'b00;
                mem_to_reg = 2'b10;  // rd = PC + 4
                jump       = 1'b1;
            end

            OP_JALR: begin
                reg_write  = 1'b1;
                alu_src    = 1'b1;   // target = rs1 + imm
                alu_op     = 2'b00;  // ADD
                mem_to_reg = 2'b10;  // rd = PC + 4
                jump       = 1'b1;
            end

            OP_LUI: begin
                reg_write  = 1'b1;
                alu_src    = 1'b1;
                alu_op     = 2'b11;  // LUI pass-through
                mem_to_reg = 2'b00;
                lui        = 1'b1;
            end

            OP_AUIPC: begin
                reg_write  = 1'b1;
                alu_src    = 1'b1;
                alu_op     = 2'b00;  // PC + upper-imm
                mem_to_reg = 2'b00;
                auipc      = 1'b1;
            end

            default: begin
                // NOP — all signals remain at safe defaults
            end
        endcase
    end

endmodule
