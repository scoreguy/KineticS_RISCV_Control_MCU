// ============================================================
// Module : register_file
// Desc   : RV32I register file.
//   - 32 registers × 32 bits
//   - x0 hardwired to zero (writes ignored)
//   - 2 asynchronous read ports  (rs1, rs2)
//   - 1 synchronous  write port  (rd, on posedge clk)
// ============================================================
`timescale 1ns/1ps

module register_file (
    input  wire        clk,
    input  wire        rst,

    // Write port
    input  wire        reg_write,
    input  wire [4:0]  rd_addr,
    input  wire [31:0] rd_data,

    // Read port 1 (rs1)
    input  wire [4:0]  rs1_addr,
    output wire [31:0] rs1_data,

    // Read port 2 (rs2)
    input  wire [4:0]  rs2_addr,
    output wire [31:0] rs2_data
);

    reg [31:0] regs [0:31];

    integer i;

    // Synchronous write — x0 is never overwritten
    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < 32; i = i + 1)
                regs[i] <= 32'b0;
        end
        else if (reg_write && rd_addr != 5'b00000) begin
            regs[rd_addr] <= rd_data;
        end
    end

    // Asynchronous reads — x0 always returns 0
    assign rs1_data = (rs1_addr == 5'b0) ? 32'b0 : regs[rs1_addr];
    assign rs2_data = (rs2_addr == 5'b0) ? 32'b0 : regs[rs2_addr];

endmodule
