`timescale 1ns/1ps
// Educational, self-checking sequence. No external vector files required.
module tb_mac_basic;
    reg clk=0, rst=1, enable=1, valid=0;
    always #4 clk=~clk;
    reg [1:0] op=0;
    reg signed [31:0] a=0, b=0, load_value=0;
    reg signed_mode=1, saturate=0, round_nearest=0;
    reg [7:0] shift=0;
    wire ready, busy, done;
    wire signed [31:0] acc;
    reg signed [31:0] expected=0;
    integer step=0;

    mac_core dut (
        .clk(clk), .rst(rst), .enable(enable),
        .cmd_valid(valid), .cmd_ready(ready), .cmd_op(op),
        .a(a), .b(b), .load_value(load_value),
        .signed_mode(signed_mode), .saturate(saturate),
        .round_nearest(round_nearest), .shift(shift),
        .busy(busy), .done(done), .acc(acc)
    );

    task command;
        input [1:0] operation;
        input signed [31:0] x, y, initial_value, answer;
        begin
            @(negedge clk);
            while(!ready) @(negedge clk);
            step=step+1;
            op=operation; a=x; b=y; load_value=initial_value;
            expected=answer; valid=1;
            @(posedge clk); #1;
            if(!busy || done) $fatal(1,"acceptance failure");
            @(negedge clk); valid=0;
            @(posedge clk); #1;
            if(!done || busy || acc!==expected)
                $fatal(1,"step %0d: actual=%0d expected=%0d",step,acc,expected);
            $display("PASS step %0d: op=%0d a=%0d b=%0d acc=%0d expected=%0d",step,op,a,b,acc,expected);
            // Hold operands and result for easy waveform inspection.
            repeat(5) @(negedge clk);
        end
    endtask

    initial begin
        repeat(3) @(negedge clk);
        if(acc!==0) $fatal(1,"reset did not clear accumulator");
        rst=0;
        command(1, 0, 0, 0, 0);       // Clear
        command(0, 3, 4, 0, 12);      // 0 + 3*4 = 12
        command(0, 2, 5, 0, 22);      // 12 + 2*5 = 22
        command(0,-2, 3, 0, 16);      // 22 + (-2)*3 = 16
        command(2, 0, 0,100,100);     // Load 100
        command(0, 7, 6, 0,142);      // 100 + 7*6 = 142
        command(1, 0, 0, 0, 0);       // Clear for a standalone multiply
        command(0, 7, 6, 0, 42);      // 0 + 7*6 = 42
        $display("PASS BASIC MAC: all 8 steps passed");
        $finish;
    end
    initial begin #10000; $fatal(1,"basic test timeout"); end
endmodule
