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
    localparam PRODUCT_W = 2 * (OPERAND_W + 1);
    localparam SUM_W = (PRODUCT_W > ACC_W ? PRODUCT_W : ACC_W) + 2;
    localparam signed [SUM_W-1:0] ONE = 1;
    localparam signed [SUM_W-1:0] SIGNED_MIN = -(ONE << (ACC_W - 1));
    localparam signed [SUM_W-1:0] SIGNED_MAX = (ONE << (ACC_W - 1)) - 1;
    localparam signed [SUM_W-1:0] UNSIGNED_MAX = (ONE << ACC_W) - 1;

    // One extra bit lets the multiplier handle both signed and unsigned inputs.
    wire signed [OPERAND_W:0] operand_a = {signed_mode & a[OPERAND_W-1], a};
    wire signed [OPERAND_W:0] operand_b = {signed_mode & b[OPERAND_W-1], b};
    reg signed [PRODUCT_W-1:0] product;
    reg [1:0] operation;
    reg [ACC_W-1:0] saved_load;
    reg [7:0] saved_shift;
    reg use_signed, use_rounding, use_saturation;

    assign cmd_ready = enable && !rst && !busy;

    // Scale the product, add the old accumulator, then clamp if requested.
    reg signed [SUM_W-1:0] total;
    always @* begin
        total = product;
        if (use_rounding && saved_shift > 0 && saved_shift < SUM_W)
            total = total + (ONE << (saved_shift - 1));
        total = (total >>> saved_shift) + $signed({use_signed & acc[ACC_W-1], acc});

        if (use_saturation) begin
            if (use_signed && total < SIGNED_MIN) total = SIGNED_MIN;
            if (use_signed && total > SIGNED_MAX) total = SIGNED_MAX;
            if (!use_signed && total > UNSIGNED_MAX) total = UNSIGNED_MAX;
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            acc  <= 0;
            busy <= 0;
            done <= 0;
        end else begin
            done <= 0;
            if (busy) begin
                // Second edge: publish the result of the saved command.
                case (operation)
                    0: acc <= total[ACC_W-1:0];
                    1: acc <= 0;
                    2: acc <= saved_load;
                    default: ;  // Reserved command holds the accumulator.
                endcase
                busy <= 0;
                done <= 1;
            end else if (cmd_valid && cmd_ready) begin
                // First edge: capture everything needed for this command.
                product        <= operand_a * operand_b;
                operation      <= cmd_op;
                saved_load     <= load_value;
                saved_shift    <= shift;
                use_signed     <= signed_mode;
                use_rounding   <= round_nearest;
                use_saturation <= saturate;
                busy           <= 1;
            end
        end
    end
endmodule
