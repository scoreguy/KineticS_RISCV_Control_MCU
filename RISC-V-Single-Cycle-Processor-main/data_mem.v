// ============================================================
// Module : data_mem
// Desc   : Data memory (RAM).
//   - 256 words × 32 bits = 1 KB
//   - Synchronous write (on posedge clk)
//   - Asynchronous read (combinational)
//   - Supports byte, halfword, word access (funct3 selects)
//
// funct3 encoding (matches RV32I):
//   3'b000  LB  / SB    byte  (sign-extend on load)
//   3'b001  LH  / SH    halfword (sign-extend on load)
//   3'b010  LW  / SW    word
//   3'b100  LBU          byte   (zero-extend)
//   3'b101  LHU          halfword (zero-extend)
// ============================================================
`timescale 1ns/1ps

module data_mem #(
    parameter DEPTH = 256
)(
    input  wire        clk,
    input  wire        mem_read,
    input  wire        mem_write,
    input  wire [2:0]  funct3,          // width/sign select
    input  wire [31:0] addr,            // byte address
    input  wire [31:0] write_data,      // data to write (rs2)
    output reg  [31:0] read_data        // data read (to WB MUX)
);

    reg [7:0] mem [0:(DEPTH*4)-1];      // byte-addressed storage

    // ---------------------------------------------------------
    // Synchronous write
    // ---------------------------------------------------------
    always @(posedge clk) begin
        if (mem_write) begin
            case (funct3)
                3'b000: begin                                   // SB — store byte
                    mem[addr]   <= write_data[7:0];
                end
                3'b001: begin                                   // SH — store halfword
                    mem[addr]   <= write_data[7:0];
                    mem[addr+1] <= write_data[15:8];
                end
                3'b010: begin                                   // SW — store word
                    mem[addr]   <= write_data[7:0];
                    mem[addr+1] <= write_data[15:8];
                    mem[addr+2] <= write_data[23:16];
                    mem[addr+3] <= write_data[31:24];
                end
                default: ;
            endcase
        end
    end

    // ---------------------------------------------------------
    // Asynchronous read with sign/zero extension
    // ---------------------------------------------------------
    always @(*) begin
        read_data = 32'b0;
        if (mem_read) begin
            case (funct3)
                3'b000:                                         // LB — sign-extend byte
                    read_data = {{24{mem[addr][7]}}, mem[addr]};

                3'b001:                                         // LH — sign-extend halfword
                    read_data = {{16{mem[addr+1][7]}},
                                  mem[addr+1], mem[addr]};

                3'b010:                                         // LW — full word
                    read_data = {mem[addr+3], mem[addr+2],
                                  mem[addr+1], mem[addr]};

                3'b100:                                         // LBU — zero-extend byte
                    read_data = {24'b0, mem[addr]};

                3'b101:                                         // LHU — zero-extend halfword
                    read_data = {16'b0, mem[addr+1], mem[addr]};

                default: read_data = 32'b0;
            endcase
        end
    end

endmodule
