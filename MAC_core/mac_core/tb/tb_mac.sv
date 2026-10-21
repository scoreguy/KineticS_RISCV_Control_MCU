`timescale 1ns/1ps
module tb_mac;
 parameter W=32, AW=32;
 reg clk=0,rst=1,enable=1,valid=0;
 always #4 clk=~clk;
 reg [1:0] op;
 reg [W-1:0] a,b;
 reg [AW-1:0] load_value;
 reg sm,sat,rnd;
 reg [7:0] shift;
 wire ready,busy,done;
 wire [AW-1:0] acc;
 mac_core #(.OPERAND_W(W),.ACC_W(AW)) dut(clk,rst,enable,valid,ready,op,a,b,
        load_value,sm,sat,rnd,shift,busy,done,acc);
 integer f,n,oi,mi,sh,count=0;
 reg [AW-1:0] expected,old;
 reg [1023:0] filename;
 initial begin
   if(!$value$plusargs("VECTORS=%s",filename))filename="C:/Users/AZHAR/nexus_one/MAC_core/mac_core/golden/mac_32_32.txt";
   f=$fopen(filename,"r"); if(!f) $fatal(1,"open MAC vectors");
   repeat(2) @(negedge clk); rst=0;
   while(!$feof(f)) begin
     n=$fscanf(f,"%d %h %h %h %d %d %h\n",oi,a,b,load_value,mi,sh,expected);
     if(n!=7) $fatal(1,"bad MAC vector");
     op=oi; sm=mi & 1; sat=(mi>>1)&1; rnd=(mi>>2)&1; shift=sh;
     // Disabled commands must not be accepted; valid held until ready.
     old=acc; enable=0; valid=1;
     @(posedge clk); #1;
     if(ready || busy || acc!==old) $fatal(1,"disable contract");
     @(negedge clk); enable=1;
     @(posedge clk); #1;
     if(!busy || done || ready) $fatal(1,"accept contract");
     @(negedge clk); valid=0; a=~a; b=~b; load_value=~load_value;
     @(posedge clk); #1;
     if(busy || !done || acc!==expected) $fatal(1,"MAC vector %0d got=%h expected=%h",count,acc,expected);
     @(negedge clk); count=count+1;
   end
   // Reset aborts a command already in flight.
   valid=1; op=0; a=7; b=9;
   @(posedge clk); #1;
   @(negedge clk); rst=1; valid=0;
   @(posedge clk); #1;
   if(acc!==0 || busy || done || ready) $fatal(1,"reset abort");
   $display("PASS MAC W=%0d AW=%0d: %0d model vectors, disable/latching/reset",W,AW,count);
   $finish;
 end
 initial begin #100000000; $fatal(1,"timeout"); end
endmodule
