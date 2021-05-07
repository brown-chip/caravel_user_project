`default_nettype none

`timescale 1 ns / 1 ps

`include "uprj_netlists.v"
`include "caravel_netlists.v"

module multiplier_tb;

    localparam BITS = 9;
    localparam KERNEL_SIZE = 3;
    localparam period = 20;

    reg clk, out_en;
    reg [KERNEL_SIZE*KERNEL_SIZE*BITS-1:0] shift_in, kernel_in;
    wire [BITS-1:0] pixel_out;
    wire output_valid;

    multiplier #(
        .BITS(BITS),
        .KERNEL_SIZE(KERNEL_SIZE)
    ) UUT (
        .clk(clk),
        .out_en(out_en),
        .shift_in(shift_in),
        .kernel_in(kernel_in),
        .output_valid(output_valid),
        .pixel_out(pixel_out)
    );    

always 
begin
    clk = 1'b1; 
    #(period/2); // high for 20 * timescale

    clk = 1'b0;
    #(period/2); // low for 20 * timescale
end

initial begin

    // test 1: All 0s
    // shift_in: [ 0 0 0; 0 0 0; 0 0 0]
    // kernel_in [ 0 0 0; 0 0 0; 1 1 1]

    shift_in = 0;
    kernel_in = 0;
    #period;

    // display message if output not matched
    if(pixel_out [BITS-1:0] != BITS-1'h0)  
        $display("[Multiplier]: test failed for all 0s");

    // test 2: All 1s (decimal)
    // shift_in: [ 1 1 1; 1 1 1; 1 1 1]
    // kernel_in [ 1 1 1; 1 1 1; 1 1 1]
    shift_in = {(KERNEL_SIZE*KERNEL_SIZE){9'd1}};
    kernel_in = {(KERNEL_SIZE*KERNEL_SIZE){9'd1}};
    #period;

    if(pixel_out != 9)  
        $display("[Multiplier]: test failed for all 1s");

    // test 3: Overflow
    // shift_in: [ 255 255 255; 255 255 255; 255 255 255]
    // kernel_in [ 255 255 255; 255 255 255; 255 255 255]

    shift_in = {(KERNEL_SIZE*KERNEL_SIZE){9'd255}};
    kernel_in = {(KERNEL_SIZE*KERNEL_SIZE){9'd255}};
    #period;

    if(pixel_out != 9'd255)  
        $display("[Multiplier]: test failed for overflow");

    // test 4: Underflow
    // shift_in: [ -256 -256 -256; -256 -256 -256; -256 -256 -256]
    // kernel_in [ -256 -256 -256; -256 -256 -256; -256 -256 -256]

    shift_in = {(KERNEL_SIZE*KERNEL_SIZE){-9'd256}};
    kernel_in = {(KERNEL_SIZE*KERNEL_SIZE){-9'd256}};
    #period;

    if(pixel_out != -9'd256)  
        $display("[Multiplier]: test failed for underflow");

    $finish;
end	

endmodule

`default_nettype wire