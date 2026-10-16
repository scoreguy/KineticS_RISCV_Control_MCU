// ============================================================
// Module : branch_control
// Desc   : Evaluates the branch condition for all 6 RV32I
//          branch instructions using ALU output flags.
//
// The ALU computes (rs1 - rs2) for all branches.
// We derive the condition from the result flags.
//
// funct3  Instruction  Condition
// 3'b000  BEQ          rs1 == rs2  →  zero == 1
// 3'b001  BNE          rs1 != rs2  →  zero == 0
// 3'b100  BLT          rs1 <  rs2 (signed)  →  negative XOR overflow
// 3'b101  BGE          rs1 >= rs2 (signed)  →  NOT (negative XOR overflow)
// 3'b110  BLTU         rs1 <  rs2 (unsigned) → borrow/carry
// 3'b111  BGEU         rs1 >= rs2 (unsigned) → NOT borrow
// ============================================================
`timescale 1ns/1ps

module branch_control (
    input  wire        branch,       // from control unit
    input  wire [2:0]  funct3,       // branch type
    input  wire        zero,         // ALU zero flag
    input  wire        negative,     // ALU result[31]
    input  wire        overflow,     // signed overflow from ALU sub
    input  wire        carry,        // unsigned borrow (for BLTU/BGEU)
    output wire        take_branch   // 1 = update PC to branch target
);

    reg condition;

    always @(*) begin
        case (funct3)
            3'b000: condition = zero;                          // BEQ
            3'b001: condition = ~zero;                         // BNE
            3'b100: condition = negative ^ overflow;           // BLT  (signed)
            3'b101: condition = ~(negative ^ overflow);        // BGE  (signed)
            3'b110: condition = ~carry;                        // BLTU (unsigned, borrow)
            3'b111: condition = carry;                         // BGEU (unsigned)
            default: condition = 1'b0;
        endcase
    end

    assign take_branch = branch & condition;

endmodule
