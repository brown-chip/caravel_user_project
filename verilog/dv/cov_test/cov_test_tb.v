`default_nettype none

`timescale 1 ns / 1 ps

`include "uprj_netlists.v"
`include "caravel_netlists.v"

module cov_test_tb;

    localparam BITS = 32;
    localparam KERNEL_SIZE = 3;
    localparam period = 20;

    reg clk, out_en;
    reg[KERNEL_SIZE*KERNEL_SIZE*BITS-1:0] shift_in, kernel_in
    reg[BITS-1:0] pixel_out;

    multiplier UUT (.clk(clk), .out_eb(out_eb), .shift_in(shift_in), .kernel_in(kernel_in), .pixel_out(pixel_out));    

always 
begin
    clk = 1'b1; 
    #20; // high for 20 * timescale

    clk = 1'b0;
    #20; // low for 20 * timescale
end

always @(posedge clk)
begin

    // test 1: 
    shift_in [287:0] = 288'h0;
    kernel_in [287:0] = 288'h0;
    #period

    // display message if output not matched
    if(pixel_out [31:0] != 32'h0)  
        $display("[Multiplier]: test failed for shift_in of 288'h0 and kernel_in of 288'h0");

    // test 2:
    shift_in [287:0] = 288'h0;
    kernel_in [287:0] = 288'h0;
    #period

    // display message if output not matched
    if(pixel_out [31:0] != 32'h0)  
        $display("[Multiplier]: test failed for shift_in of 288'h0 and kernel_in of 288'h0");
end	


endmodule
`default_nettype wire
