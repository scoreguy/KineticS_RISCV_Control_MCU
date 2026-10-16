// ============================================================
// Module : imm_gen
// Desc   : Extracts and sign-extends the immediate value from
//          a 32-bit RV32I instruction word.
//
// Formats handled:
//   I-type : ADDI, SLTI, loads, JALR
//   S-type : SW, SH, SB
//   B-type : BEQ, BNE, BLT, BGE, BLTU, BGEU
//   U-type : LUI, AUIPC
//   J-type : JAL
// ============================================================
`timescale 1ns/1ps

module imm_gen (
    input  wire [31:0] instr,     // full 32-bit instruction word
    output reg  [31:0] imm_ext   // 32-bit sign-extended immediate
);

    wire [6:0] opcode = instr[6:0];

    localparam OP_I_ARITH= 7'b0010011;
    localparam OP_LOAD   = 7'b0000011;
    localparam OP_JALR   = 7'b1100111;
    localparam OP_STORE  = 7'b0100011;
    localparam OP_BRANCH = 7'b1100011;
    localparam OP_LUI    = 7'b0110111;
    localparam OP_AUIPC  = 7'b0010111;
    localparam OP_JAL    = 7'b1101111;

    always @(*) begin
        case (opcode)

            // I-type: imm[11:0] = instr[31:20]
            OP_I_ARITH,
            OP_LOAD,
            OP_JALR:
                imm_ext = {{20{instr[31]}}, instr[31:20]};

            // S-type: imm[11:5] = instr[31:25], imm[4:0] = instr[11:7]
            OP_STORE:
                imm_ext = {{20{instr[31]}}, instr[31:25], instr[11:7]};

            // B-type: imm[12|10:5] = instr[31:25], imm[4:1|11] = instr[11:7]
            // NOTE: bit 0 is always 0 (branch targets are 2-byte aligned)
            OP_BRANCH:
                imm_ext = {{19{instr[31]}},
                           instr[31],
                           instr[7],
                           instr[30:25],
                           instr[11:8],
                           1'b0};

            // U-type: upper 20 bits, lower 12 are zero
            OP_LUI,
            OP_AUIPC:
                imm_ext = {instr[31:12], 12'b0};

            // J-type: imm[20|10:1|11|19:12]
            // NOTE: bit 0 is always 0 (jump targets are 2-byte aligned)
            OP_JAL:
                imm_ext = {{11{instr[31]}},
                           instr[31],
                           instr[19:12],
                           instr[20],
                           instr[30:21],
                           1'b0};

            default:
                imm_ext = 32'b0;
        endcase
    end

endmodule
