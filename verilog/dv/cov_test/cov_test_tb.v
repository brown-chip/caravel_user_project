`default_nettype none

`timescale 1 ns / 1 ps

`include "uprj_netlists.v"
`include "caravel_netlists.v"

module cov_test_tb;

    localparam BITS = 9;
    localparam KERNEL_SIZE = 3;
    localparam period = 20;

    reg clk, out_en;
    reg [KERNEL_SIZE*KERNEL_SIZE*BITS-1:0] shift_in, kernel_in;
    wire [BITS-1:0] pixel_out;

    multiplier #(
        .BITS(BITS),
        .KERNEL_SIZE(KERNEL_SIZE)
    ) UUT (
        .clk(clk),
        .out_en(out_en),
        .shift_in(shift_in),
        .kernel_in(kernel_in),
        .pixel_out(pixel_out)
    );    

always 
begin
    clk = 1'b1; 
    #20; // high for 20 * timescale

    clk = 1'b0;
    #20; // low for 20 * timescale
end

initial begin

    // test 1: All 0s
    // shift_in: [ 0 0 0; 0 0 0; 0 0 0]
    // kernel_in [ 0 0 0; 0 0 0; 1 1 1]

    shift_in = 0;
    kernel_in = 0;
    #period

    // display message if output not matched
    if(pixel_out [BITS-1:0] != BITS-1'h0)  
        $display("[Multiplier]: test failed for all 0s");

    // test 2: All 1s (decimal)
    // shift_in: [ 1 1 1; 1 1 1; 1 1 1]
    // kernel_in [ 1 1 1; 1 1 1; 1 1 1]
    shift_in = {(KERNEL_SIZE*KERNEL_SIZE){9'd1}};
    kernel_in = {(KERNEL_SIZE*KERNEL_SIZE){9'd1}};
    #period

    if(pixel_out != 9)  
        $display("[Multiplier]: test failed for all 1s");

    // test 3: Overflow
    // shift_in: [ 255 255 255; 255 255 255; 255 255 255]
    // kernel_in [ 255 255 255; 255 255 255; 255 255 255]

    shift_in = {(KERNEL_SIZE*KERNEL_SIZE){9'd255}};
    kernel_in = {(KERNEL_SIZE*KERNEL_SIZE){9'd255}};
    #period

    if(pixel_out != 9'd255)  
        $display("[Multiplier]: test failed for overflow");

    // test 4: Underflow
    // shift_in: [ -256 -256 -256; -256 -256 -256; -256 -256 -256]
    // kernel_in [ -256 -256 -256; -256 -256 -256; -256 -256 -256]

    shift_in = {(KERNEL_SIZE*KERNEL_SIZE){-9'd256}};
    kernel_in = {(KERNEL_SIZE*KERNEL_SIZE){-9'd256}};
    #period

    if(pixel_out != -9'd256)  
        $display("[Multiplier]: test failed for underflow");

    $finish;
end	

endmodule
`default_nettype wire

module convolve_tb();
    // Main convolution module testbench for entire project

    // I think that this one will be similar to the shift register in which we 
    // employ some slick python to generate the image that we expect and then 
    // also to wrap the output of this convolve_tb. That is, that we reconstruct
    // some picture at the end of this with said convolution. This will make 
    // it easier to tell what is going on and what everything is.
    // TODO: Since we assume that everything else works in this case, we just
    //       need to test on a system wide level rather than unit testing
    // TODO: Probably just a few pictures and then some edge case pictures

    // We need to make sure that it is handling the edges and sides correctly 
    
    // Also try and put in some nonsymmetric kernels. We should be testing to 
    // make sure it works on all kernels (presumably) and not just some kernels
endmodule

module shift_register_tb();
    // Shift register testbench

    // For this one, it might make sense for us to just load in an image and
    // then work from there. That is, we have some python that outputs the 
    // kernel for each convolution loop and then we can take a look at that
    // and make sure that the shift register is working correctly
    // TODO: We need to make sure that reset is working
    // TODO: Check if write enable is correct
    // TODO: Check the ready logic
    // TODO: Check that we actually get the output that we want out of our 
    //       module (regular test)

endmodule

module kernel_mem_tb();
    // Kernel memory testbench

    //     module kernel_mem #(
    //     parameter BITS = 8,
    //     parameter KERNEL_SIZE = 3
    // )(
    //     input clk,
    //     input reset,
    //     input write_en,
    //     input [BITS-1:0] kernel_in,
    //     output ready,
    //     output [KERNEL_SIZE*KERNEL_SIZE*BITS-1:0] out
    // );

    // Parameters
    parameter BITS = 9;
    parameter KERNEL_SIZE = 3;

    // Input Output wires
    reg clk, reset, write_en;
    reg [BITS-1:0] kernel_in;
    wire ready;
    wire [KERNEL_SIZE*KERNEL_SIZE*BITS-1:0] out;

    // Loop inputs
    integer i;
    integer j;

    // Declaration of Module
    kernel_mem uut(clk, 
                   reset,
                   write_en,
                   kernel_in,
                   ready,
                   out);

    // Begin testbench
    initial begin
        #0 clk = 1'b1;
        #0 reset = 1'b0;
        #0 kernel_in = 8'hff;
        #0 write_en = 1'b0;
        j = 0;
        
        // Reset module to start testing
        #1 reset = 1'b1;
        #1 reset = 1'b0;

        // Check if output is all 0s 
        if (out != 0) begin
            $display("Error encountered with reset. Out is not all reset to zeroes");
            j = j + 1;
        end

        // Check Ready Logic
        if (ready != 1'b0) begin
            $display("Error encountered with ready signal");
            j = j + 1;
        end

        // Test write enable
        #1;
        if (out != 0) begin
            $display("Error encountered with write_en. Still writing to output kernel");
            j = j + 1;
        end

        // Check Ready
        #1 write_en = 1'b1;
        #9;     // FIXME: Not sure whether or not we can change this to be kernel_size * kernel_size later

        if (ready != 1'b1) begin
            $display("Error encountered with ready signal. Waited (KERNEL_SIZE * KERNEL_SIZE) amount of time, yet no ready signal");
            j = j + 1;
        end

        // Reset;
        #1;
        write_en = 1'b0;
        reset = 1'b1;
        #1 reset = 1'b0;

        // Normal Test of kernel to check everything is correct
        #1;
        write_en = 1'b1;

        for (i = 1; i < (KERNEL_SIZE * KERNEL_SIZE); i = i + 1) begin
            #1 kernel_in = i;
        end

        // output should be 9, 8, 7, 6, 5, 4, 3, 2, 1
        $display("Output from kernel_mem: %d", out);    // TODO: Should find better way of doing this later on

        if (j == 0) begin
            $display("All tests for kernel_mem pass!");
        end
        
        $finish;
    end

    // Clock
    always #0.5 clk <= ~clk;
endmodule

