module PID(
    input signed [7:0] Kp, Ki, Kd,
    input signed [15:0] current_value, set_point,
    input [7:0] Ts,
    input [15:0] Gd,
    input clk,
    input rst,
    output reg signed [31:0] out
);

reg signed [31:0] Proportional;
reg signed [31:0] Integral_prev;
reg signed [31:0] Derivative;
reg signed [31:0] Integral_curr;
reg signed [15:0] Error_prev;

// ✅ use combinational error (fix timing issue)
wire signed [15:0] error;
assign error = set_point - current_value;

// ✅ limits to prevent overflow
parameter signed MAX = 32'sd100000;
parameter signed MIN = -32'sd100000;

reg signed [31:0] sum;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        Proportional  <= 0;
        Integral_prev <= 0;
        Integral_curr <= 0;
        Derivative    <= 0;
        Error_prev    <= 0;
        out           <= 0;
    end else begin 

        //////////////////////////////////////////////////
        // 🔹 Proportional (scaled)
        //////////////////////////////////////////////////
        Proportional <= (Kp * error);

        //////////////////////////////////////////////////
        // 🔹 Integral (scaled to avoid explosion)
        //////////////////////////////////////////////////
        Integral_curr <= Integral_prev + ((Ki * error) >>> 4);

        //////////////////////////////////////////////////
        // 🔹 Derivative (scaled)
        //////////////////////////////////////////////////
        Derivative <= (Kd * (error - Error_prev)) >>> 2;

        //////////////////////////////////////////////////
        // 🔹 Sum + CLAMP (CRITICAL FIX)
        //////////////////////////////////////////////////
        sum = Proportional + Integral_curr + Derivative;

        if (sum > MAX)
            out <= MAX;
        else if (sum < MIN)
            out <= MIN;
        else
            out <= sum;

        //////////////////////////////////////////////////
        // 🔹 Update state
        //////////////////////////////////////////////////
        Integral_prev <= Integral_curr;
        Error_prev <= error;

    end
end

endmodule