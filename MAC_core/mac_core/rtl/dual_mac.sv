`timescale 1ns/1ps
// Each lane scores a different digit from the same incoming pixel.
module dual_mac (
    input wire clk, rst, valid,
    input wire [1:0] op,
    input wire signed [31:0] pixel, weight0, weight1, bias0, bias1,
    output wire ready, done,
    output wire signed [31:0] score0, score1
);
    // Both cores receive identical control signals, so their timing is identical.
    mac_core lane0 (
        .clk(clk), .rst(rst), .enable(1'b1), .cmd_valid(valid), .cmd_ready(ready),
        .cmd_op(op), .a(pixel), .b(weight0), .load_value(bias0),
        .signed_mode(1'b1), .saturate(1'b0), .round_nearest(1'b0), .shift(8'd0),
        .busy(), .done(done), .acc(score0)
    );
    mac_core lane1 (
        .clk(clk), .rst(rst), .enable(1'b1), .cmd_valid(valid), .cmd_ready(),
        .cmd_op(op), .a(pixel), .b(weight1), .load_value(bias1),
        .signed_mode(1'b1), .saturate(1'b0), .round_nearest(1'b0), .shift(8'd0),
        .busy(), .done(), .acc(score1)
    );
endmodule
