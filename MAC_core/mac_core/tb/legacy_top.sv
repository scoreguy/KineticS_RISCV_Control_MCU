// Recovered commented legacy wrapper; duplicate port declarations removed.
`timescale 1ns/1ps

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