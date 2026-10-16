// ============================================================
// Module : alu_control
// Desc   : Decodes opcode + funct3 + funct7[5] into 4-bit
//          alu_ctrl signal for the ALU.
//
// alu_op (from main control):
//   2'b00  → ADD  (loads, stores, AUIPC, JAL, JALR)
//   2'b01  → SUB  (branches — zero flag tells BEQ/BNE/etc.)
//   2'b10  → look at funct3 + funct7 (R-type and I-type arith)
//   2'b11  → LUI  pass-through
// ============================================================
`timescale 1ns/1ps

module alu_control (
    input  wire [1:0] alu_op,     // from main control unit
    input  wire [2:0] funct3,     // instruction bits [14:12]
    input  wire       funct7_5,   // instruction bit  [30]  (SUB vs ADD, SRA vs SRL)
    output reg  [3:0] alu_ctrl    // to ALU
);

    always @(*) begin
        case (alu_op)
            2'b00: alu_ctrl = 4'b0000;   // ADD  — loads/stores/AUIPC/JAL/JALR
            2'b01: alu_ctrl = 4'b0001;   // SUB  — branches (a-b, check zero)
            2'b11: alu_ctrl = 4'b1010;   // LUI  pass-through

            2'b10: begin                  // R-type and I-type arithmetic
                case (funct3)
                    3'b000: alu_ctrl = (funct7_5) ? 4'b0001 : 4'b0000; // SUB/ADD  ADDI
                    3'b001: alu_ctrl = 4'b0101;   // SLL  / SLLI
                    3'b010: alu_ctrl = 4'b1000;   // SLT  / SLTI
                    3'b011: alu_ctrl = 4'b1001;   // SLTU / SLTIU
                    3'b100: alu_ctrl = 4'b0100;   // XOR  / XORI
                    3'b101: alu_ctrl = (funct7_5) ? 4'b0111 : 4'b0110; // SRA/SRL  SRAI/SRLI
                    3'b110: alu_ctrl = 4'b0011;   // OR   / ORI
                    3'b111: alu_ctrl = 4'b0010;   // AND  / ANDI
                    default: alu_ctrl = 4'b0000;
                endcase
            end

            default: alu_ctrl = 4'b0000;
        endcase
    end

endmodule
