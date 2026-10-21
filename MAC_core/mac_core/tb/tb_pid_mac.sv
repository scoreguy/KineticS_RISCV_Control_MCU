`timescale 1ns/1ps
// Fake CPU owns ALL PID state; DUT contains only one general MAC.
// A logical PID sample advances once per completed four-axis frame.
module tb_pid_mac;  
 reg clk=0,rst=1;
 always #4 clk=~clk;
 reg valid=0,write=0;
 reg [7:0] addr=0;
 reg [31:0] wdata=0;
 wire ready,err,busy,done;
 wire [31:0] rdata,result;
 mac_regs dut(.clk(clk),.rst(rst),.bus_valid(valid),.bus_write(write),
  .bus_addr(addr),.bus_wdata(wdata),.bus_ready(ready),.bus_rdata(rdata),.bus_error(err),
  .stream_valid(1'b0),.stream_ready(),.stream_op(2'd0),.stream_a(32'd0),
  .stream_b(32'd0),.stream_load(32'd0),.stream_mode(11'd0),.result(result),.busy(busy),.done(done));
 integer cycles=0;
 always @(posedge clk) cycles=cycles+1;
 task bus_wr(input [7:0] ad,input [31:0] data);
 begin
   @(negedge clk); valid=1; write=1; addr=ad; wdata=data;
   @(posedge clk); while(!ready) @(posedge clk);
   if(err) $fatal(1,"bus write error");
   @(negedge clk); valid=0;
 end endtask
 task bus_rd(input [7:0] ad,output [31:0] data);
 begin
   @(negedge clk); valid=1; write=0; addr=ad;
   @(posedge clk); while(!ready) @(posedge clk);
   if(err) $fatal(1,"bus read error"); data=rdata;
   @(negedge clk); valid=0;
 end endtask
 reg [31:0] status;
 task wait_result(output [31:0] value);
 begin
   status=0;
   while(!status[1]) bus_rd(8'h14,status);
   bus_rd(8'h18,value);
 end endtask
 task multiply(input signed [31:0] x,y,initial_acc,input integer sh,output reg signed [31:0] value);
 reg [31:0] dummy;
 begin
   bus_wr(8'h08,initial_acc); bus_wr(8'h10,2); wait_result(dummy);
   bus_wr(8'h00,x); bus_wr(8'h04,y); bus_wr(8'h0c,1 | (sh<<3));
   bus_wr(8'h10,0); wait_result(value);
 end endtask
 reg signed [31:0] pold[0:3],icurr[0:3],iprev[0:3],dold[0:3];
 reg signed [15:0] eprev[0:3];
 reg signed [15:0] e;
 reg signed [31:0] pnew,inew,dnew,sum,actual,delta;
 reg [31:0] expected;
 integer closed_fb[0:3],last_actual[0:3],next_fb,trace;
 integer f,g,n,k,r,s,fb,kp,ki,kd,count=0,start_cycle,frame_start,axis_cycles=0,frame_cycles=0;
 initial begin
   f=$fopen("C:/Users/AZHAR/nexus_one/MAC_core/mac_core/golden/stimulus.txt","r");g=$fopen("C:/Users/AZHAR/nexus_one/MAC_core/mac_core/golden/original.txt","r");
   if(!f || !g) $fatal(1,"PID files");
   trace=$fopen("C:/Users/AZHAR/nexus_one/MAC_core/mac_core/golden/closed_loop.csv","w");
   if(!trace) $fatal(1,"trace file");
   $fdisplay(trace,"sample,axis,feedback,original_output,mac_output");
   closed_fb[0]=400; closed_fb[1]=-250; closed_fb[2]=600; closed_fb[3]=-300;
   for(k=0;k<4;k=k+1) last_actual[k]=0;
   repeat(2) @(negedge clk); rst=0;
   while(!$feof(f)) begin
     frame_start=cycles;
     for(k=0;k<4;k=k+1) begin
       n=$fscanf(f,"%d %d %d %d %d %d\n",r,s,fb,kp,ki,kd);
       if(n!=6) $fatal(1,"stimulus");
       n=$fscanf(g,"%h\n",expected); if(n!=1) $fatal(1,"golden");
       if(count/4<=500) begin
         if(fb!==closed_fb[k]) $fatal(1,"closed-loop trajectory mismatch");
         fb=closed_fb[k]; // Drive from plant state maintained from MAC outputs.
       end
       start_cycle=cycles;
       if(r) begin
         pold[k]=0; icurr[k]=0; iprev[k]=0; dold[k]=0; eprev[k]=0; actual=0;
         @(negedge clk); rst=1;
         @(negedge clk); rst=0;
       end else begin
         e=s-fb;
         sum=pold[k]+icurr[k]+dold[k];
         if(sum>100000) actual=100000;
         else if(sum< -100000) actual=-100000;
         else actual=sum;
         delta=$signed(e)-$signed(eprev[k]);
         multiply(kp,e,0,0,pnew);
         multiply(ki,e,iprev[k],4,inew);
         multiply(kd,delta,0,2,dnew);
         pold[k]=pnew; iprev[k]=icurr[k]; icurr[k]=inew;
         dold[k]=dnew; eprev[k]=e;
         axis_cycles=cycles-start_cycle;
       end
       if(actual!==expected) $fatal(1,"PID sample %0d axis %0d got=%h expected=%h",count,k,actual,expected);
       if(count/4<=500) begin
         $fdisplay(trace,"%0d,%0d,%0d,%0d,%0d",count/4,k,fb,$signed(expected),actual);
         if(!r) begin
           next_fb=closed_fb[k]-(last_actual[k]>>>10)-(closed_fb[k]>>>4);
           if(next_fb>1000) next_fb=1000;
           if(next_fb< -1000) next_fb=-1000;
           closed_fb[k]=next_fb;
         end
         last_actual[k]=actual;
       end
       count=count+1;
     end
     if(!r) frame_cycles=cycles-frame_start;
   end
   if(!$feof(g)) $fatal(1,"extra golden records");
   $fclose(trace);
   $display("PASS shared-MAC PID: %0d axis samples match original RTL",count);
   $display("MEASURED fake-CPU schedule: %0d cycles/axis, %0d cycles/4-axis frame",axis_cycles,frame_cycles);
   $finish;
 end
 initial begin #1000000000; $fatal(1,"timeout PID"); end
endmodule
