`timescale 1ns/1ps
module tb_regs;
 reg clk=0,rst=1,bv=0,bw=0,sv=0;
 always #4 clk=~clk;
 reg [7:0] ba=0;
 reg [31:0] wd=0,sa=0,sb=0,sl=0;
 reg [1:0] so=0;
 reg [10:0] sm=1;
 wire br,be,sr,busy,done;
 wire [31:0] rd,result;
 mac_regs dut(clk,rst,bv,bw,ba,wd,br,rd,be,sv,sr,so,sa,sb,sl,sm,result,busy,done);
 task wr(input [7:0] address,input [31:0] data,input expect_error);
 begin
   @(negedge clk); bv=1; bw=1; ba=address; wd=data;
   @(posedge clk); while(!br) @(posedge clk);
   if(be!==expect_error) $fatal(1,"bus error semantics");
   @(negedge clk); bv=0;
 end endtask
 task check(input [7:0] address,input [31:0] expected);
 begin
   @(negedge clk); bv=1; bw=0; ba=address;
   @(posedge clk);
   if(!br || be || rd!==expected) $fatal(1,"read %h got %h expected %h",address,rd,expected);
   @(negedge clk); bv=0;
 end endtask
 initial begin
   repeat(2) @(negedge clk); rst=0;
   check(24,0); check(12,1);
   wr(0,7,0); wr(4,-3,0); wr(12,1,0);
   wr(1,9,1); wr(24,9,1); wr(16,3,1);
   // Simultaneous stream and bus command: stream wins, bus waits.
   @(negedge clk); sv=1; so=0; sa=2; sb=5; bv=1; bw=1; ba=16; wd=0;
   #1; if(!sr || br) $fatal(1,"arbitration");
   @(posedge clk); #1;
   if(!busy || result!==0) $fatal(1,"stream acceptance");
   @(negedge clk); sv=0;
   @(posedge clk); #1;
   if(result!==10 || !done) $fatal(1,"stream result");
   // Held bus request accepted next edge and uses registered 7 * -3.
   @(posedge clk); #1;
   if(!busy) $fatal(1,"held bus request lost");
   @(negedge clk); bv=0;
   @(posedge clk); #1;
   if(result!==32'hfffffff5) $fatal(1,"bus result");
   check(20,2); check(24,32'hfffffff5);
   wr(20,2,0); check(20,0);
   // Continuous valid supplies commands only at ready edges.
   @(negedge clk); sv=1; so=1;
   @(posedge clk); @(negedge clk); so=0; sa=3; sb=4;
   @(posedge clk); @(posedge clk); @(negedge clk); sv=0;
   @(posedge clk); #1; if(result!==12) $fatal(1,"back-to-back stream");
   // Bus writes while arithmetic is active cannot change latched operands.
   wr(16,0,0); wr(0,100,0); check(24,32'hfffffff7);
   @(negedge clk); sv=1; so=0;
   @(posedge clk); @(negedge clk); rst=1; sv=0;
   @(posedge clk); #1;
   if(result!==0 || busy || done || br || sr) $fatal(1,"wrapper reset");
   $display("PASS register/stream arbitration, errors, sticky status, held requests, reset");
   $finish;
 end
 initial begin #100000; $fatal(1,"timeout registers"); end
endmodule
