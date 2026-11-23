/*`timescale 1ns/1ps

module top_4pid_pwm(

    input clk,
    input rst,

    // Setpoints
    input signed [15:0] set_roll,
    input signed [15:0] set_pitch,
    input signed [15:0] set_yaw,
    input signed [15:0] set_z,

    // Feedback
    input signed [15:0] fb_roll,
    input signed [15:0] fb_pitch,
    input signed [15:0] fb_yaw,
    input signed [15:0] fb_z,

    //////////////////////////////////////////////////
    // INDEPENDENT PID GAINS (FIXED)
    //////////////////////////////////////////////////

    // Roll
    input signed [7:0] Kp_roll, Ki_roll, Kd_roll,

    // Pitch
    input signed [7:0] Kp_pitch, Ki_pitch, Kd_pitch,

    // Yaw
    input signed [7:0] Kp_yaw, Ki_yaw, Kd_yaw,

    // Z
    input signed [7:0] Kp_z, Ki_z, Kd_z,

    //////////////////////////////////////////////////
    // OUTPUTS
    //////////////////////////////////////////////////

    // PWM
    output pwm_roll,
    output pwm_pitch,
    output pwm_yaw,
    output pwm_z,

    // Direction
    output dir_roll,
    output dir_pitch,
    output dir_yaw,
    output dir_z,

    // PID outputs
    output signed [31:0] out_roll,
    output signed [31:0] out_pitch,
    output signed [31:0] out_yaw,
    output signed [31:0] out_z
);

//////////////////////////////////////////////////
// PID OUTPUT WIRES (FIXED)
//////////////////////////////////////////////////
wire signed [31:0] out_roll;
wire signed [31:0] out_pitch;
wire signed [31:0] out_yaw;
wire signed [31:0] out_z;

//////////////////////////////////////////////////
// PID INSTANCES (ALL INDEPENDENT NOW)
//////////////////////////////////////////////////

PID pid_roll (
    .clk(clk),
    .rst(rst),
    .set_point(set_roll),
    .current_value(fb_roll),
    .Kp(Kp_roll), .Ki(Ki_roll), .Kd(Kd_roll),
    .out(out_roll)
);

PID pid_pitch (
    .clk(clk),
    .rst(rst),
    .set_point(set_pitch),
    .current_value(fb_pitch),
    .Kp(Kp_pitch), .Ki(Ki_pitch), .Kd(Kd_pitch),
    .out(out_pitch)
);

PID pid_yaw (
    .clk(clk),
    .rst(rst),
    .set_point(set_yaw),
    .current_value(fb_yaw),
    .Kp(Kp_yaw), .Ki(Ki_yaw), .Kd(Kd_yaw),
    .out(out_yaw)
);

PID pid_z (
    .clk(clk),
    .rst(rst),
    .set_point(set_z),
    .current_value(fb_z),
    .Kp(Kp_z), .Ki(Ki_z), .Kd(Kd_z),
    .out(out_z)
);

//////////////////////////////////////////////////
// PWM INSTANCES
//////////////////////////////////////////////////

pwm pwm_roll_inst (
    .clk(clk),
    .rst(rst),
    .pid_out(out_roll),
    .pwm_out(pwm_roll),
    .dir(dir_roll)
);

pwm pwm_pitch_inst (
    .clk(clk),
    .rst(rst),
    .pid_out(out_pitch),
    .pwm_out(pwm_pitch),
    .dir(dir_pitch)
);

pwm pwm_yaw_inst (
    .clk(clk),
    .rst(rst),
    .pid_out(out_yaw),
    .pwm_out(pwm_yaw),
    .dir(dir_yaw)
);

pwm pwm_z_inst (
    .clk(clk),
    .rst(rst),
    .pid_out(out_z),
    .pwm_out(pwm_z),
    .dir(dir_z)
);
endmodule
*/
`timescale 1ns/1ps

module top_final (

    input clk   // only required FPGA input

);

//////////////////////////////////////////////////
// INTERNAL RESET (NO EXTERNAL RESET)
//////////////////////////////////////////////////

wire rst = 1'b0;

//////////////////////////////////////////////////
// INTERNAL SIGNALS
//////////////////////////////////////////////////

// Setpoints
wire signed [15:0] set_roll  = 0;
wire signed [15:0] set_pitch = 0;
wire signed [15:0] set_yaw   = 0;
wire signed [15:0] set_z     = 0;

// Feedback (large offsets for visible behavior)
reg signed [15:0] fb_roll  = 1200;
reg signed [15:0] fb_pitch = -600;
reg signed [15:0] fb_yaw   = 900;
reg signed [15:0] fb_z     = -1500;

// Gains
wire signed [7:0] Kp = 4;
wire signed [7:0] Ki = 0;
wire signed [7:0] Kd = 2;

// Outputs (internal only)
wire pwm_roll, pwm_pitch, pwm_yaw, pwm_z;
wire dir_roll, dir_pitch, dir_yaw, dir_z;

wire signed [31:0] out_roll;
wire signed [31:0] out_pitch;
wire signed [31:0] out_yaw;
wire signed [31:0] out_z;

//////////////////////////////////////////////////
// PID INSTANCES
//////////////////////////////////////////////////

PID pid_roll (
    .clk(clk),
    .rst(rst),
    .set_point(set_roll),
    .current_value(fb_roll),
    .Kp(Kp), .Ki(Ki), .Kd(Kd),
    .out(out_roll)
);

PID pid_pitch (
    .clk(clk),
    .rst(rst),
    .set_point(set_pitch),
    .current_value(fb_pitch),
    .Kp(Kp), .Ki(Ki), .Kd(Kd),
    .out(out_pitch)
);

PID pid_yaw (
    .clk(clk),
    .rst(rst),
    .set_point(set_yaw),
    .current_value(fb_yaw),
    .Kp(Kp), .Ki(Ki), .Kd(Kd),
    .out(out_yaw)
);

PID pid_z (
    .clk(clk),
    .rst(rst),
    .set_point(set_z),
    .current_value(fb_z),
    .Kp(Kp), .Ki(Ki), .Kd(Kd),
    .out(out_z)
);

//////////////////////////////////////////////////
// PWM INSTANCES
//////////////////////////////////////////////////

pwm pwm_roll_inst (
    .clk(clk),
    .rst(rst),
    .pid_out(out_roll),
    .pwm_out(pwm_roll),
    .dir(dir_roll)
);

pwm pwm_pitch_inst (
    .clk(clk),
    .rst(rst),
    .pid_out(out_pitch),
    .pwm_out(pwm_pitch),
    .dir(dir_pitch)
);

pwm pwm_yaw_inst (
    .clk(clk),
    .rst(rst),
    .pid_out(out_yaw),
    .pwm_out(pwm_yaw),
    .dir(dir_yaw)
);

pwm pwm_z_inst (
    .clk(clk),
    .rst(rst),
    .pid_out(out_z),
    .pwm_out(pwm_z),
    .dir(dir_z)
);

//////////////////////////////////////////////////
// SIMPLE CLOSED-LOOP PLANT
//////////////////////////////////////////////////

always @(posedge clk) begin
    fb_roll  <= fb_roll  - (out_roll  >>> 9);
    fb_pitch <= fb_pitch - (out_pitch >>> 10);
    fb_yaw   <= fb_yaw   - (out_yaw   >>> 11);
    fb_z     <= fb_z     - (out_z     >>> 8);
end

//////////////////////////////////////////////////
// ILA (ONLY 4 PROBES)
//////////////////////////////////////////////////

ila_0 ila_inst (
    .clk(clk),

    .probe0({31'd0, pwm_roll}),
    .probe1({31'd0, pwm_pitch}),
    .probe2({31'd0, pwm_yaw}),
    .probe3({31'd0, pwm_z})
);

endmodule