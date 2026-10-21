`timescale 1ns/1ps
// Robotic Arm with Propeller Thrust - Final Testbench with Sample & Cycle Totals
module tb_propeller_arm_pid;  
 reg clk=0, rst=1;
 always #4 clk=~clk; // 8ns clock period
 
 reg valid=0, write=0;
 reg [7:0] addr=0;
 reg [31:0] wdata=0;
 wire ready, err, busy, done;
 wire [31:0] rdata, result;
 
 mac_regs dut(
   .clk(clk), .rst(rst),
   .bus_valid(valid), .bus_write(write),
   .bus_addr(addr), .bus_wdata(wdata),
   .bus_ready(ready), .bus_rdata(rdata), .bus_error(err),
   .stream_valid(1'b0), .stream_ready(),
   .stream_op(2'd0), .stream_a(32'd0), .stream_b(32'd0),
   .stream_load(32'd0), .stream_mode(11'd0),
   .result(result), .busy(busy), .done(done)
 );
 
 integer cycles=0;
 always @(posedge clk) cycles = cycles + 1;

 task bus_wr(input [7:0] ad, input [31:0] data);
 begin
   @(negedge clk); valid=1; write=1; addr=ad; wdata=data;
   @(posedge clk); while(!ready) @(posedge clk);
   if(err) $fatal(1, "bus write error");
   @(negedge clk); valid=0;
 end endtask

 task bus_rd(input [7:0] ad, output [31:0] data);
 begin
   @(negedge clk); valid=1; write=0; addr=ad;
   @(posedge clk); while(!ready) @(posedge clk);
   if(err) $fatal(1, "bus read error"); 
   data=rdata;
   @(negedge clk); valid=0;
 end endtask

 reg [31:0] status=0;
 task wait_result(output [31:0] value);
 begin
   status=0;
   while(!status[1]) bus_rd(8'h14, status);
   bus_rd(8'h18, value);
 end endtask

 // Hardware MAC Task
 task multiply_hw(
   input integer x, input integer y, input integer initial_acc, input integer sh, 
   output reg signed [31:0] value, output integer elapsed_cycles
 );
 reg [31:0] dummy;
 integer start_c;
 begin
   start_c = cycles;
   bus_wr(8'h08, initial_acc); bus_wr(8'h10, 2); wait_result(dummy);
   bus_wr(8'h00, x); bus_wr(8'h04, y); bus_wr(8'h0c, 1 | (sh<<3));
   bus_wr(8'h10, 0); wait_result(value);
   elapsed_cycles = cycles - start_c;
 end endtask

 // PID State Variables
 reg signed [31:0] pold=0, icurr=0, iprev=0, dold=0;
 reg signed [15:0] eprev=0;
 reg signed [15:0] e=0;
 reg signed [31:0] pnew=0, inew=0, dnew=0, sum=0, actual=0, delta=0;
 
 // Arm & Propeller Physical Parameters
 integer target_angle = 450;  
 integer current_theta = 0;   
 integer last_actual = 0, next_theta = 0;
 integer kp = 15, ki = 2, kd = 8; 
 
 // Benchmarking Counters
 integer hw_p_cyc=0, hw_i_cyc=0, hw_d_cyc=0, hw_sample_cyc=0;
 integer total_hw_cycles=0;
 integer sample=0, steady_count=0;
 integer max_samples = 400;

 initial begin
   $display("==========================================================================");
   $display("[START] Propeller Arm Angle Control Simulation (Frictionless Physics)");
   $display("[CONFIG] Target Angle = %0d | Initial Arm Angle = %0d", target_angle, current_theta);
   $display("==========================================================================");

   repeat(4) @(negedge clk); 
   rst = 0;
   @(negedge clk);

   while (sample < max_samples && steady_count < 20) begin
     e = target_angle - current_theta;
     
     sum = pold + icurr + dold;
     if (sum > 50000) actual = 50000;
     else if (sum < 0) actual = 0; 
     else actual = sum;
     
     delta = $signed(e) - $signed(eprev);
     
     multiply_hw(kp, e, 0, 0, pnew, hw_p_cyc);
     multiply_hw(ki, e, icurr, 0, inew, hw_i_cyc);       
     multiply_hw(kd, delta, 0, 0, dnew, hw_d_cyc);
     
     hw_sample_cyc = hw_p_cyc + hw_i_cyc + hw_d_cyc;
     total_hw_cycles = total_hw_cycles + hw_sample_cyc;

     pold = pnew; 
     iprev = icurr; 
     icurr = inew;
     dold = dnew; 
     eprev = e;

     next_theta = current_theta + (last_actual >>> 8) - (current_theta >>> 5);
     if (next_theta < 0) next_theta = 0; 
     
     $display("Sample: %3d | Arm Angle (Theta): %4d | Target: %4d | Err: %4d | Propeller Thrust: %5d | HW_Cyc: %0d", 
              sample, current_theta, target_angle, e, actual, hw_sample_cyc);

     current_theta = next_theta;
     last_actual = actual;

     if (e >= -2 && e <= 2) steady_count = steady_count + 1;
     else steady_count = 0;

     sample = sample + 1;
   end

   $display("==========================================================================");
   $display("[SIMULATION COMPLETE]");
   $display("  * Total Samples Processed : %0d", sample);
   $display("  * Total Clock Cycles Run  : %0d cycles", cycles);
   $display("  * Total Hardware MAC Cycles: %0d cycles", total_hw_cycles);
   $display("==========================================================================");
   $finish;
 end

 initial begin #2000000000; $fatal(1, "timeout arm simulation"); end
endmodule