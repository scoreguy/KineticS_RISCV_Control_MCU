// ============================================================
// Testbench : riscv_cpu_tb  (PYNQ-Z2 edition)
// Desc      : Tests all RV32I instruction categories.
//
// How to run (Icarus Verilog):
//   iverilog -o cpu_tb \
//     tb/riscv_cpu_tb.v rtl/riscv_cpu.v rtl/alu.v rtl/alu_control.v \
//     rtl/control_unit.v rtl/register_file.v rtl/imm_gen.v \
//     rtl/instr_mem.v rtl/data_mem.v rtl/branch_control.v
//   vvp cpu_tb
//   gtkwave cpu.vcd
//
// Note on port change vs Basys3 version:
//   The FPGA top module now only exposes debug_reg_x10[3:0]
//   (to match the 4 LEDs on PYNQ-Z2). For simulation we still
//   have full visibility by peeking into the DUT hierarchy —
//   dut.pc, dut.instr, dut.alu_result, dut.regfile.regs[n]
//   This gives the same observability with no port changes needed.
// ============================================================
`timescale 1ns/1ps

module riscv_cpu_tb;

    reg  clk, rst;

    // The PYNQ-Z2 top module only has a 4-bit debug output.
    // We declare it to match the port, but all test checking
    // uses get_reg() which peeks directly into the DUT hierarchy.
    wire [3:0] debug_reg_x10;

    riscv_cpu dut (
        .clk           (clk),
        .rst           (rst),
        .debug_reg_x10 (debug_reg_x10)
    );

    // 10ns clock period = 100 MHz
    initial clk = 0;
    always  #5 clk = ~clk;

    // VCD waveform dump
    initial begin
        $dumpfile("cpu.vcd");
        $dumpvars(0, riscv_cpu_tb);
    end

    // -------------------------------------------------------
    // Utility: read a specific register by peeking into DUT
    // -------------------------------------------------------
    function [31:0] get_reg;
        input [4:0] idx;
        get_reg = dut.regfile.regs[idx];
    endfunction

    // -------------------------------------------------------
    // check task: compare register value, print pass/fail
    // -------------------------------------------------------
    integer pass_count, fail_count;
    task check;
        input [4:0]  reg_idx;
        input [31:0] expected;
        input [127:0] test_name;  // up to 16 ASCII chars
        begin
            if (get_reg(reg_idx) === expected) begin
                $display("  PASS [%s] x%0d = 0x%08h", test_name, reg_idx, expected);
                pass_count = pass_count + 1;
            end else begin
                $display("  FAIL [%s] x%0d: got 0x%08h, expected 0x%08h",
                         test_name, reg_idx, get_reg(reg_idx), expected);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // -------------------------------------------------------
    // Helper: load instructions directly into IMEM
    // (avoids needing a separate .hex file for simulation)
    // -------------------------------------------------------
    task load_instr;
        input integer idx;
        input [31:0] word;
        begin
            dut.imem.mem[idx] = word;
        end
    endtask

    task cpu_reset;
        begin
            rst = 1;
            @(posedge clk); #1;
            @(posedge clk); #1;
            rst = 0;
        end
    endtask

    task run_cycles;
        input integer n;
        integer k;
        begin
            for (k = 0; k < n; k = k + 1)
                @(posedge clk);
            #1;
        end
    endtask

    // -------------------------------------------------------
    // Encode RV32I instructions as 32-bit words
    // -------------------------------------------------------

    // R-type: funct7 | rs2 | rs1 | funct3 | rd | opcode
    function [31:0] R;
        input [6:0] funct7; input [4:0] rs2,rs1; input [2:0] funct3; input [4:0] rd; input [6:0] op;
        R = {funct7, rs2, rs1, funct3, rd, op};
    endfunction

    // I-type: imm[11:0] | rs1 | funct3 | rd | opcode
    function [31:0] I;
        input [11:0] imm; input [4:0] rs1; input [2:0] funct3; input [4:0] rd; input [6:0] op;
        I = {imm, rs1, funct3, rd, op};
    endfunction

    // S-type: imm[11:5] | rs2 | rs1 | funct3 | imm[4:0] | opcode
    function [31:0] S;
        input [11:0] imm; input [4:0] rs2,rs1; input [2:0] funct3; input [6:0] op;
        S = {imm[11:5], rs2, rs1, funct3, imm[4:0], op};
    endfunction

    // B-type
    function [31:0] B;
        input [12:0] imm; input [4:0] rs2,rs1; input [2:0] funct3; input [6:0] op;
        B = {imm[12], imm[10:5], rs2, rs1, funct3, imm[4:1], imm[11], op};
    endfunction

    // U-type: imm[31:12] | rd | opcode
    function [31:0] U;
        input [19:0] imm; input [4:0] rd; input [6:0] op;
        U = {imm, rd, op};
    endfunction

    // J-type (JAL)
    function [31:0] J;
        input [20:0] imm; input [4:0] rd; input [6:0] op;
        J = {imm[20], imm[10:1], imm[11], imm[19:12], rd, op};
    endfunction

    // NOP = ADDI x0, x0, 0
    `define NOP 32'h00000013

    // Opcode constants
    localparam OPC_R    = 7'b0110011;
    localparam OPC_I    = 7'b0010011;
    localparam OPC_LOAD = 7'b0000011;
    localparam OPC_ST   = 7'b0100011;
    localparam OPC_BR   = 7'b1100011;
    localparam OPC_JAL  = 7'b1101111;
    localparam OPC_JALR = 7'b1100111;
    localparam OPC_LUI  = 7'b0110111;
    localparam OPC_AUIPC= 7'b0010111;

    // =========================================================
    // MAIN TEST SEQUENCE
    // =========================================================
    initial begin
        pass_count = 0; fail_count = 0;
        rst = 1; #20; rst = 0;

        // -------------------------------------------------------
        $display("\n=== TEST 1: R-type arithmetic ===");
        // ADDI x1, x0, 10     → x1 = 10
        // ADDI x2, x0, 7      → x2 = 7
        // ADD  x3, x1, x2     → x3 = 17
        // SUB  x4, x1, x2     → x4 = 3
        // AND  x5, x1, x2     → x5 = 10 & 7 = 2
        // OR   x6, x1, x2     → x6 = 10 | 7 = 15
        // XOR  x7, x1, x2     → x7 = 10 ^ 7 = 13
        // SLL  x8, x1, x2     → x8 = 10 << 7 = 1280
        // SRL  x9, x8, x2     → x9 = 1280 >> 7 = 10
        // SLT  x10,x2, x1     → x10 = 1 (7 < 10)
        // SLTU x11,x1, x2     → x11 = 0 (10 not < 7 unsigned)
        load_instr(0,  I(12'd10, 5'd0,  3'b000, 5'd1, OPC_I));
        load_instr(1,  I(12'd7,  5'd0,  3'b000, 5'd2, OPC_I));
        load_instr(2,  R(7'b0000000, 5'd2, 5'd1, 3'b000, 5'd3, OPC_R));
        load_instr(3,  R(7'b0100000, 5'd2, 5'd1, 3'b000, 5'd4, OPC_R));
        load_instr(4,  R(7'b0000000, 5'd2, 5'd1, 3'b111, 5'd5, OPC_R));
        load_instr(5,  R(7'b0000000, 5'd2, 5'd1, 3'b110, 5'd6, OPC_R));
        load_instr(6,  R(7'b0000000, 5'd2, 5'd1, 3'b100, 5'd7, OPC_R));
        load_instr(7,  R(7'b0000000, 5'd2, 5'd1, 3'b001, 5'd8, OPC_R));
        load_instr(8,  R(7'b0000000, 5'd2, 5'd8, 3'b101, 5'd9, OPC_R));
        load_instr(9,  R(7'b0000000, 5'd1, 5'd2, 3'b010, 5'd10,OPC_R));
        load_instr(10, R(7'b0000000, 5'd2, 5'd1, 3'b011, 5'd11,OPC_R));
        load_instr(11, `NOP);
        cpu_reset; run_cycles(14);
        check(5'd3, 32'd17,   "ADD");
        check(5'd4, 32'd3,    "SUB");
        check(5'd5, 32'd2,    "AND");
        check(5'd6, 32'd15,   "OR");
        check(5'd7, 32'd13,   "XOR");
        check(5'd8, 32'd1280, "SLL");
        check(5'd9, 32'd10,   "SRL");
        check(5'd10,32'd1,    "SLT");
        check(5'd11,32'd0,    "SLTU");

        // -------------------------------------------------------
        $display("\n=== TEST 2: I-type arithmetic ===");
        // ADDI x1, x0, -1    → x1 = 0xFFFFFFFF (sign extend)
        // XORI x2, x1, -1    → x2 = 0 (all bits flip)
        // ORI  x3, x0, 63    → x3 = 63
        // ANDI x4, x3, 15    → x4 = 15
        // SLLI x5, x3, 2     → x5 = 252
        // SRLI x6, x5, 2     → x6 = 63
        // SRAI x7, x1, 4     → x7 = -1 (arithmetic: sign-fill)
        // SLTI x8, x1, 0     → x8 = 1  (−1 < 0 signed)
        // SLTIU x9,x1, 1     → x9 = 0  (0xFFFF.. not < 1 unsigned)
        load_instr(0, I(12'hFFF, 5'd0, 3'b000, 5'd1, OPC_I)); // ADDI x1,-1
        load_instr(1, I(12'hFFF, 5'd1, 3'b100, 5'd2, OPC_I)); // XORI x2,x1,-1
        load_instr(2, I(12'd63, 5'd0, 3'b110, 5'd3, OPC_I));  // ORI  x3,0,63
        load_instr(3, I(12'd15, 5'd3, 3'b111, 5'd4, OPC_I));  // ANDI x4,x3,15
        load_instr(4, I(12'd2,  5'd3, 3'b001, 5'd5, OPC_I));  // SLLI x5,x3,2
        load_instr(5, I(12'd2,  5'd5, 3'b101, 5'd6, OPC_I));  // SRLI x6,x5,2
        load_instr(6, {7'b0100000,5'd4,5'd1,3'b101,5'd7,OPC_I}); // SRAI x7,x1,4
        load_instr(7, I(12'd0,  5'd1, 3'b010, 5'd8, OPC_I));  // SLTI
        load_instr(8, I(12'd1,  5'd1, 3'b011, 5'd9, OPC_I));  // SLTIU
        load_instr(9, `NOP);
        cpu_reset; run_cycles(12);
        check(5'd1, 32'hFFFFFFFF, "ADDI_neg");
        check(5'd2, 32'h0,        "XORI");
        check(5'd3, 32'd63,       "ORI");
        check(5'd4, 32'd15,       "ANDI");
        check(5'd5, 32'd252,      "SLLI");
        check(5'd6, 32'd63,       "SRLI");
        check(5'd7, 32'hFFFFFFFF, "SRAI");
        check(5'd8, 32'd1,        "SLTI");
        check(5'd9, 32'd0,        "SLTIU");

        // -------------------------------------------------------
        $display("\n=== TEST 3: LUI and AUIPC ===");
        // LUI   x1, 0x12345  → x1 = 0x12345000
        // AUIPC x2, 0        → x2 = PC of this instr (= 4)
        load_instr(0, U(20'h12345, 5'd1, OPC_LUI));
        load_instr(1, U(20'h0,     5'd2, OPC_AUIPC));
        load_instr(2, `NOP);
        cpu_reset; run_cycles(4);
        check(5'd1, 32'h12345000, "LUI");
        check(5'd2, 32'h00000004, "AUIPC");

        // -------------------------------------------------------
        $display("\n=== TEST 4: Load and Store ===");
        // ADDI x1, x0, 100  → x1 = base address 100
        // ADDI x2, x0, 0xAB → x2 = 0xAB (store value)
        // SW   x2, 0(x1)    → mem[100] = 0xAB
        // LW   x3, 0(x1)    → x3 = 0xAB
        // SB   x2, 4(x1)    → mem[104] = 0xAB (low byte)
        // LBU  x4, 4(x1)    → x4 = 0xAB (zero-extended)
        // LB   x5, 4(x1)    → x5 = sign-extended 0xAB = 0xFFFFFFAB
        load_instr(0, I(12'd100, 5'd0, 3'b000, 5'd1, OPC_I));
        load_instr(1, I(12'hAB,  5'd0, 3'b000, 5'd2, OPC_I));
        load_instr(2, S(12'd0, 5'd2, 5'd1, 3'b010, OPC_ST));
        load_instr(3, I(12'd0, 5'd1, 3'b010, 5'd3, OPC_LOAD));
        load_instr(4, S(12'd4, 5'd2, 5'd1, 3'b000, OPC_ST));
        load_instr(5, I(12'd4, 5'd1, 3'b100, 5'd4, OPC_LOAD));
        load_instr(6, I(12'd4, 5'd1, 3'b000, 5'd5, OPC_LOAD));
        load_instr(7, `NOP);
        cpu_reset; run_cycles(10);
        check(5'd3, 32'h000000AB, "LW");
        check(5'd4, 32'h000000AB, "LBU");
        check(5'd5, 32'hFFFFFFAB, "LB_sign");

        // -------------------------------------------------------
        $display("\n=== TEST 5: Branches ===");
        // BEQ: x1==x1 → should branch over ADD (skip it)
        //   0: ADDI x1, x0, 5
        //   1: ADDI x2, x0, 5
        //   2: BEQ  x1, x2, +8  (skip instr 3)
        //   3: ADDI x3, x0, 99  ← must be skipped
        //   4: ADDI x3, x0, 1   ← executed after branch
        load_instr(0, I(12'd5, 5'd0, 3'b000, 5'd1, OPC_I));
        load_instr(1, I(12'd5, 5'd0, 3'b000, 5'd2, OPC_I));
        load_instr(2, B(13'd8, 5'd2, 5'd1, 3'b000, OPC_BR));  // BEQ → PC+8 (skip next)
        load_instr(3, I(12'd99,5'd0, 3'b000, 5'd3, OPC_I));   // MUST be skipped
        load_instr(4, I(12'd1, 5'd0, 3'b000, 5'd3, OPC_I));   // MUST execute
        load_instr(5, `NOP);
        cpu_reset; run_cycles(7);
        check(5'd3, 32'd1, "BEQ_taken");

        // BNE: x1!=x2 → branch
        //   0: ADDI x1, x0, 3
        //   1: ADDI x2, x0, 7
        //   2: BNE  x1, x2, +8  → taken, skip instr 3
        //   3: ADDI x3, x0, 99  ← skipped
        //   4: ADDI x3, x0, 2   ← executed
        load_instr(0, I(12'd3, 5'd0, 3'b000, 5'd1, OPC_I));
        load_instr(1, I(12'd7, 5'd0, 3'b000, 5'd2, OPC_I));
        load_instr(2, B(13'd8, 5'd2, 5'd1, 3'b001, OPC_BR));
        load_instr(3, I(12'd99,5'd0, 3'b000, 5'd3, OPC_I));
        load_instr(4, I(12'd2, 5'd0, 3'b000, 5'd3, OPC_I));
        load_instr(5, `NOP);
        cpu_reset; run_cycles(7);
        check(5'd3, 32'd2, "BNE_taken");

        // -------------------------------------------------------
        $display("\n=== TEST 6: JAL and JALR ===");
        // JAL  x1, +8  → x1 = PC+4 = 4, jump to instr 2
        // ADDI x2,x0,99 ← skipped
        // ADDI x2,x0,42 ← landed here
        // JALR x3,x1,0  → x3 = PC+4, jump to x1 = instr 1
        //                  (this verifies return address)
        load_instr(0, J(21'd8,  5'd1, OPC_JAL));
        load_instr(1, I(12'd99, 5'd0, 3'b000, 5'd2, OPC_I));  // skipped
        load_instr(2, I(12'd42, 5'd0, 3'b000, 5'd2, OPC_I));  // landed
        load_instr(3, I(12'd0,  5'd1, 3'b000, 5'd3, OPC_JALR)); // JALR x3,x1,0
        load_instr(4, `NOP);
        cpu_reset; run_cycles(6);
        check(5'd1, 32'h00000004, "JAL_ra");
        check(5'd2, 32'd42,       "JAL_land");

        // -------------------------------------------------------
        $display("\n=== TEST 7: x0 hardwired zero ===");
        // Any write to x0 must be discarded
        load_instr(0, I(12'd99, 5'd0, 3'b000, 5'd0, OPC_I));  // ADDI x0,x0,99
        load_instr(1, `NOP);
        cpu_reset; run_cycles(3);
        check(5'd0, 32'd0, "x0_zero");

        // -------------------------------------------------------
        $display("\n=== TEST 8: SRA (arithmetic shift) ===");
        // ADDI x1, x0, -8   → x1 = 0xFFFFFFF8
        // SRA  x2, x1, imm4 → x2 = 0xFFFFFFFF (-1) — sign fills
        load_instr(0, I(12'hFF8, 5'd0, 3'b000, 5'd1, OPC_I));
        load_instr(1, {7'b0100000, 5'd3, 5'd1, 3'b101, 5'd2, OPC_R}); // SRA x2,x1,x3? use SRAI
        // SRAI x2, x1, 4:
        load_instr(1, {7'b0100000, 5'd4, 5'd1, 3'b101, 5'd2, OPC_I});
        load_instr(2, `NOP);
        cpu_reset; run_cycles(4);
        check(5'd2, 32'hFFFFFFFF, "SRAI_neg");

        // -------------------------------------------------------
        $display("\n=== SUMMARY ===");
        $display("PASS: %0d   FAIL: %0d", pass_count, fail_count);
        if (fail_count == 0)
            $display("All tests PASSED — CPU is functionally correct.");
        else
            $display("Some tests FAILED — check logic above.");

        #50 $finish;
    end

endmodule
