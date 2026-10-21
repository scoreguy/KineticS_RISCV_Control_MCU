`timescale 1ns/1ps
module tb_golden;
 reg clk=0,rst=1;
 always #4 clk=~clk;
 reg signed [15:0] sp[0:3],fb[0:3];
 reg signed [7:0] kp[0:3],ki[0:3],kd[0:3];
 wire signed [31:0] out[0:3];
 genvar g;
 generate for(g=0;g<4;g=g+1) begin: axes
   PID dut(.clk(clk),.rst(rst),.set_point(sp[g]),.current_value(fb[g]),
           .Kp(kp[g]),.Ki(ki[g]),.Kd(kd[g]),.Ts(8'd0),.Gd(16'd0),.out(out[g]));
 end endgenerate
 integer f,o,n,axis,r,s,v,p,i,d,count=0;
 initial begin
   f=$fopen("golden/stimulus.txt","r"); o=$fopen("golden/original.txt","w");
   if(!f || !o) $fatal(1,"golden file open");
   while(!$feof(f)) begin
     @(negedge clk);
     for(axis=0;axis<4;axis=axis+1) begin
       n=$fscanf(f,"%d %d %d %d %d %d\n",r,s,v,p,i,d);
       if(n!=6) $fatal(1,"bad stimulus");
       rst=r; sp[axis]=s; fb[axis]=v; kp[axis]=p; ki[axis]=i; kd[axis]=d;
     end
     @(posedge clk); #1;
     for(axis=0;axis<4;axis=axis+1) begin
       if(^out[axis]===1'bx) $fatal(1,"unknown golden output");
       $fdisplay(o,"%08x",out[axis]); count=count+1;
     end
   end
   $fclose(f); $fclose(o); $display("PASS original RTL capture: %0d axis samples",count); $finish;
 end
 initial begin #100000000; $fatal(1,"timeout"); end
endmodule
