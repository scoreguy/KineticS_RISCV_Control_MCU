`timescale 1ns/1ps

module tb_top_4pid;

//////////////////////////////////////////////////
// Clock
//////////////////////////////////////////////////
reg clk, rst;
initial clk = 0;
always #5 clk = ~clk;

//////////////////////////////////////////////////
// Inputs
//////////////////////////////////////////////////
reg signed [15:0] set_roll  = 0;
reg signed [15:0] set_pitch = 0;
reg signed [15:0] set_yaw   = 0;
reg signed [15:0] set_z     = 0;

reg signed [15:0] fb_roll;
reg signed [15:0] fb_pitch;
reg signed [15:0] fb_yaw;
reg signed [15:0] fb_z;

//////////////////////////////////////////////////
// Gains (independent)
//////////////////////////////////////////////////
reg signed [7:0] Kp_roll, Ki_roll, Kd_roll;
reg signed [7:0] Kp_pitch, Ki_pitch, Kd_pitch;
reg signed [7:0] Kp_yaw, Ki_yaw, Kd_yaw;
reg signed [7:0] Kp_z, Ki_z, Kd_z;

//////////////////////////////////////////////////
// Outputs
//////////////////////////////////////////////////
wire pwm_roll, pwm_pitch, pwm_yaw, pwm_z;
wire dir_roll, dir_pitch, dir_yaw, dir_z;

//////////////////////////////////////////////////
// DUT
//////////////////////////////////////////////////
top_4pid_pwm dut (
    .clk(clk),
    .rst(rst),

    .set_roll(set_roll),
    .set_pitch(set_pitch),
    .set_yaw(set_yaw),
    .set_z(set_z),

    .fb_roll(fb_roll),
    .fb_pitch(fb_pitch),
    .fb_yaw(fb_yaw),
    .fb_z(fb_z),

    .Kp_roll(Kp_roll), .Ki_roll(Ki_roll), .Kd_roll(Kd_roll),
    .Kp_pitch(Kp_pitch), .Ki_pitch(Ki_pitch), .Kd_pitch(Kd_pitch),
    .Kp_yaw(Kp_yaw), .Ki_yaw(Ki_yaw), .Kd_yaw(Kd_yaw),
    .Kp_z(Kp_z), .Ki_z(Ki_z), .Kd_z(Kd_z),

    .pwm_roll(pwm_roll),
    .pwm_pitch(pwm_pitch),
    .pwm_yaw(pwm_yaw),
    .pwm_z(pwm_z),

    .dir_roll(dir_roll),
    .dir_pitch(dir_pitch),
    .dir_yaw(dir_yaw),
    .dir_z(dir_z)
);

//////////////////////////////////////////////////
// SYSTEM MODEL (4-AXIS STABLE PLANT)
//////////////////////////////////////////////////
reg signed [31:0] next_roll, next_pitch, next_yaw, next_z;

always @(posedge clk) begin
    if (!rst) begin

        // Control response
        next_roll  = fb_roll  - (dut.pid_roll.out  >>> 10);
        next_pitch = fb_pitch - (dut.pid_pitch.out >>> 10);
        next_yaw   = fb_yaw   - (dut.pid_yaw.out   >>> 10);
        next_z     = fb_z     - (dut.pid_z.out     >>> 10);

        // Damping
        next_roll  = next_roll  - (fb_roll  >>> 4);
        next_pitch = next_pitch - (fb_pitch >>> 4);
        next_yaw   = next_yaw   - (fb_yaw   >>> 4);
        next_z     = next_z     - (fb_z     >>> 4);

        // Clamp
        if (next_roll  > 1000) next_roll  = 1000;
        if (next_roll  < -1000) next_roll  = -1000;

        if (next_pitch > 1000) next_pitch = 1000;
        if (next_pitch < -1000) next_pitch = -1000;

        if (next_yaw   > 1000) next_yaw   = 1000;
        if (next_yaw   < -1000) next_yaw   = -1000;

        if (next_z     > 1000) next_z     = 1000;
        if (next_z     < -1000) next_z     = -1000;

        // Update feedback
        fb_roll  <= next_roll;
        fb_pitch <= next_pitch;
        fb_yaw   <= next_yaw;
        fb_z     <= next_z;
    end
end

//////////////////////////////////////////////////
// Simulation
//////////////////////////////////////////////////
initial begin
    $display("=== 4-AXIS PID TEST ===");

    rst = 1;

    // Initial disturbances
    fb_roll  = 400;
    fb_pitch = -250;
    fb_yaw   = 600;
    fb_z     = -300;

    // Gains (safe)
    Kp_roll  = 4; Ki_roll  = 0; Kd_roll  = 2;
    Kp_pitch = 4; Ki_pitch = 0; Kd_pitch = 2;
    Kp_yaw   = 4; Ki_yaw   = 0; Kd_yaw   = 2;
    Kp_z     = 4; Ki_z     = 0; Kd_z     = 2;

    #20 rst = 0;

    // Run simulation
    repeat (500) @(posedge clk);

    $finish;
end

//////////////////////////////////////////////////
// Monitor
//////////////////////////////////////////////////
initial begin
    $monitor("t=%0t | roll=%d pitch=%d yaw=%d z=%d",
              $time, fb_roll, fb_pitch, fb_yaw, fb_z);
end

endmodule


//new_pynq_topmod