`timescale 1ns/1ps

module tb_classifier #(parameter LANES = 1);
    localparam IMAGES = 360;  // 20% of the 1797 digits
    reg clk = 0, rst = 1, valid = 0;
    reg [1:0] op = 0;
    reg signed [31:0] pixel = 0, weight = 0, bias = 0;
    reg signed [31:0] weight1 = 0, bias1 = 0;
    wire done;
    wire signed [31:0] score1;
    wire signed [31:0] score;
    always #5 clk = ~clk;

    if (LANES == 2) begin : parallel
        dual_mac dut (
            .clk(clk), .rst(rst), .valid(valid), .op(op), .pixel(pixel),
            .weight0(weight), .weight1(weight1), .bias0(bias), .bias1(bias1),
            .ready(), .done(done), .score0(score), .score1(score1)
        );
    end else begin : single
      mac_core dut (
        .clk(clk), .rst(rst), .enable(1'b1),
        .cmd_valid(valid), .cmd_ready(), .cmd_op(op),
        .a(pixel), .b(weight), .load_value(bias),
        .signed_mode(1'b1), .saturate(1'b0), .round_nearest(1'b0),
        .shift(8'd0), .busy(), .done(done), .acc(score)
    );
    end

    reg signed [31:0] pixels [0:IMAGES*64-1];
    reg signed [31:0] weights [0:10*64-1];
    reg signed [31:0] biases [0:9];
    reg signed [31:0] expected [0:IMAGES*10-1];

    // Start one command only after the previous command has finished.
    task run_command(input [1:0] command);
        begin
            op = command;
            valid = 1;
            @(negedge clk);
            valid = 0;
            @(negedge clk);
            if (done !== 1'b1)
                $fatal(1, "MAC command did not finish");
        end
    endtask

    integer img, digit, p, images_to_run, results;
    integer cycles = 0, start_cycle;
    always @(posedge clk) cycles = cycles + 1;
    initial begin
        images_to_run = IMAGES;
        if ($test$plusargs("demo")) begin
            images_to_run = 1;
            results = $fopen("rtl_scores.txt", "w");
            $dumpfile("digit.vcd");
            $dumpvars(0, clk, valid, done, pixel, weight, score, digit);
            if (LANES == 2) $dumpvars(0, weight1, score1);
        end
        $readmemh("pixels.hex", pixels, 0, images_to_run*64-1);
        $readmemh("weights.hex", weights);
        $readmemh("bias.hex", biases);
        $readmemh("scores.hex", expected, 0, images_to_run*10-1);
        @(negedge clk);
        rst = 0;
        start_cycle = cycles;
        for (img = 0; img < images_to_run; img = img + 1) begin
            for (digit = 0; digit < 10; digit = digit + LANES) begin
                bias = biases[digit];
                if (LANES == 2) bias1 = biases[digit+1];
                run_command(2);  // Load bias into the accumulator
                for (p = 0; p < 64; p = p + 1) begin
                    pixel = pixels[img*64 + p];
                    weight = weights[digit*64 + p];
                    if (LANES == 2) weight1 = weights[(digit+1)*64 + p];
                    run_command(0);  // score += pixel * weight
                end
                if ((^score === 1'bx) || score !== expected[img*10 + digit])
                    $fatal(1, "Image %0d digit %0d: got %0d expected %0d",
                           img, digit, score, expected[img*10 + digit]);
                if ($test$plusargs("demo")) $fdisplay(results, "%0d", score);
                if (LANES == 2) begin
                    if ((^score1 === 1'bx) || score1 !== expected[img*10 + digit+1])
                        $fatal(1, "Image %0d digit %0d: got %0d expected %0d",
                               img, digit+1, score1, expected[img*10 + digit+1]);
                    if ($test$plusargs("demo")) $fdisplay(results, "%0d", score1);
                end
            end
        end
        if ($test$plusargs("demo")) $fclose(results);
        $display("%0d MAC(s): %0d cycles total, %0d cycles/image",
                 LANES, cycles-start_cycle, (cycles-start_cycle)/images_to_run);
        $display("PASS: %0d RTL scores match Python exactly.", images_to_run*10);
        $finish;
    end
endmodule
