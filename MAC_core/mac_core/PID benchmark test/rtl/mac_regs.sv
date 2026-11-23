`timescale 1ns/1ps
// Local 32-bit, full-word valid/ready bus. NOT an AXI-Lite slave.
// Stream commands have priority over bus START writes; no hidden queue.
module mac_regs (
    input wire clk,rst,
    input wire bus_valid,bus_write,
    input wire [7:0] bus_addr,
    input wire [31:0] bus_wdata,
    output wire bus_ready,
    output reg [31:0] bus_rdata,
    output wire bus_error,
    input wire stream_valid,
    output wire stream_ready,
    input wire [1:0] stream_op,
    input wire [31:0] stream_a,stream_b,stream_load,
    input wire [10:0] stream_mode,
    output wire [31:0] result,
    output wire busy,done
);
    reg [31:0] a_reg,b_reg,load_reg,mode_reg;
    reg done_sticky;
    wire core_ready;
    wire start=bus_valid && bus_write && bus_addr==8'h10;
    wire known=(bus_addr==0 || bus_addr==4 || bus_addr==8 ||
                bus_addr==12 || bus_addr==16 || bus_addr==20 || bus_addr==24);
    assign bus_error=bus_valid && (!known || (bus_write && bus_addr==24) ||
                      (start && bus_wdata>2));
    assign bus_ready=!rst && (!start || bus_error || (core_ready && !stream_valid));
    assign stream_ready=core_ready;
    wire accept_bus=start && bus_ready && !bus_error;
    wire [10:0] mode=stream_valid ? stream_mode : mode_reg[10:0];
    mac_core core (
        .clk(clk),.rst(rst),.enable(1'b1),
        .cmd_valid(stream_valid || accept_bus),.cmd_ready(core_ready),
        .cmd_op(stream_valid ? stream_op : bus_wdata[1:0]),
        .a(stream_valid ? stream_a : a_reg),.b(stream_valid ? stream_b : b_reg),
        .load_value(stream_valid ? stream_load : load_reg),
        .signed_mode(mode[0]),.saturate(mode[1]),.round_nearest(mode[2]),
        .shift(mode[10:3]),.acc(result),.busy(busy),.done(done)
    );
    always @* begin
        bus_rdata=0;
        case(bus_addr)
            0: bus_rdata=a_reg;
            4: bus_rdata=b_reg;
            8: bus_rdata=load_reg;
            12: bus_rdata=mode_reg;
            20: bus_rdata={30'd0,(done_sticky | done),busy};
            24: bus_rdata=result;
            default: bus_rdata=0;
        endcase
    end
    always @(posedge clk) begin
        if(rst) begin
            a_reg<=0; b_reg<=0; load_reg<=0; mode_reg<=1; done_sticky<=0;
        end else begin
            if(bus_valid && bus_ready && bus_write && !bus_error) begin
                case(bus_addr)
                    0: a_reg<=bus_wdata;
                    4: b_reg<=bus_wdata;
                    8: load_reg<=bus_wdata;
                    12: mode_reg<=bus_wdata & 32'h7ff;
                    20: if(bus_wdata[1]) done_sticky<=0;
                    default: ;
                endcase
            end
            if(done) done_sticky<=1;
            if((stream_valid && stream_ready) || accept_bus) done_sticky<=0;
        end
    end
endmodule
