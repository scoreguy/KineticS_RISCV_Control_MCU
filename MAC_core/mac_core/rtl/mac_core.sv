`timescale 1ns/1ps
// One multiplier. Ready/valid commands; one-cycle execute latency.
// op: 0=MAC, 1=clear, 2=load. Reset aborts in-flight work.
module mac_core #(
    parameter integer OPERAND_W=32, ACC_W=32
)(
    input wire clk, rst, enable,
    input wire cmd_valid, output wire cmd_ready,
    input wire [1:0] cmd_op,
    input wire [OPERAND_W-1:0] a, b,
    input wire [ACC_W-1:0] load_value,
    input wire signed_mode, saturate, round_nearest,
    input wire [7:0] shift,
    output reg busy, done,
    output reg [ACC_W-1:0] acc
);
    localparam integer PW=2*(OPERAND_W+1);
    localparam integer EW=(PW>ACC_W ? PW : ACC_W)+2;
    reg [1:0] op_q;
    reg [ACC_W-1:0] load_q;
    reg signed_q, sat_q, round_q;
    reg [7:0] shift_q;
    reg signed [PW-1:0] product_q;
    wire signed [OPERAND_W:0] ax={signed_mode & a[OPERAND_W-1],a};
    wire signed [OPERAND_W:0] bx={signed_mode & b[OPERAND_W-1],b};
    reg signed [EW-1:0] term, base, total, hi, lo, bias;
    reg [ACC_W-1:0] result;
    assign cmd_ready=enable && !rst && !busy;
    always @* begin
        term={{(EW-PW){product_q[PW-1]}},product_q};
        bias=0;
        // Round to nearest, ties toward +infinity; otherwise arithmetic floor.
        // Shifts >= EW are explicitly defined (no rounding addition).
        if (round_q && shift_q!=0 && shift_q<EW) begin
            bias=1;
            bias=bias << (shift_q-1);
            term=term+bias;
        end
        term=term >>> shift_q;
        base=$signed({{(EW-ACC_W){signed_q & acc[ACC_W-1]}},acc});
        total=base+term;
        hi=0; lo=0;
        if (signed_q) begin
            hi=( {{(EW-1){1'b0}},1'b1} << (ACC_W-1))-1;
            lo=-( {{(EW-1){1'b0}},1'b1} << (ACC_W-1));
        end else hi=( {{(EW-1){1'b0}},1'b1} << ACC_W)-1;
        result=total[ACC_W-1:0];
        if (sat_q && total>hi) result=hi[ACC_W-1:0];
        else if (sat_q && total<lo) result=lo[ACC_W-1:0];
    end
    always @(posedge clk) begin
        if (rst) begin
            acc<=0; busy<=0; done<=0; product_q<=0;
            op_q<=0; load_q<=0; signed_q<=0; sat_q<=0;
            round_q<=0; shift_q<=0;
        end else begin
            done<=0;
            if (busy) begin
                case(op_q)
                    0: acc<=result;
                    1: acc<=0;
                    2: acc<=load_q;
                    default: acc<=acc;
                endcase
                busy<=0; done<=1;
            end else if (cmd_valid && cmd_ready) begin
                product_q<=ax*bx;
                op_q<=cmd_op; load_q<=load_value;
                signed_q<=signed_mode; sat_q<=saturate;
                round_q<=round_nearest; shift_q<=shift;
                busy<=1;
            end
        end
    end
endmodule
