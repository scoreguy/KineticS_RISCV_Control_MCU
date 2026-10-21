`timescale 1ns/1ps

module pwm(
    input clk,
    input rst,

    // PID output
    input signed [31:0] pid_out,

    output reg pwm_out,
    output reg [7:0] counter1,
    output dir
);

//////////////////////////////////////////////////
// Direction (sign)
//////////////////////////////////////////////////
assign dir = (pid_out < 0);

//////////////////////////////////////////////////
// Magnitude
//////////////////////////////////////////////////
wire [31:0] mag;
assign mag = (pid_out < 0) ? -pid_out : pid_out;

//////////////////////////////////////////////////
// Scaling
//////////////////////////////////////////////////
parameter SHIFT = 8;

wire [31:0] scaled;
assign scaled = mag >> SHIFT;

//////////////////////////////////////////////////
// Clamp
//////////////////////////////////////////////////
wire [7:0] duty;
assign duty = (scaled > 255) ? 8'd255 : scaled[7:0];

//////////////////////////////////////////////////
// 🔥 SLOW CLOCK GENERATOR
//////////////////////////////////////////////////

reg [23:0] clk_div;

always @(posedge clk or posedge rst) begin
    if (rst)
        clk_div <= 0;
    else
        clk_div <= clk_div + 1;
end

// Choose bit for PWM speed
wire slow_clk = clk_div[15];   // adjust this (14–18 range)

/*
//////////////////////////////////////////////////
// PWM LOGIC (runs on slow clock)
//////////////////////////////////////////////////

always @(posedge slow_clk or posedge rst) begin
    if (rst) begin
        counter1 <= 0;
        pwm_out <= 0;
    end else begin
        counter1 <= counter1 + 1;

        if (counter1 < duty)
            pwm_out <= 1;
        else
            pwm_out <= 0;
    end
end

endmodule*/
//////////////////////////////////////////////////
// PWM generation
//////////////////////////////////////////////////

always @(posedge clk or posedge rst) begin
    if (rst) begin
        counter1 <= 0;
        pwm_out <= 0;
    end else begin
        counter1 <= counter1 + 1;

        // optional better timing (uses next value)
        pwm_out <= ((counter1 + 1) < duty);
    end
end

endmodule

