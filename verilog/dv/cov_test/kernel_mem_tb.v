`default_nettype none

`timescale 1 ns / 1 ps

`include "uprj_netlists.v"
`include "caravel_netlists.v"

module kernel_mem_tb();
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
            $display("[kernel_mem]: Error encountered with reset. Out is not all reset to zeroes");
            j = j + 1;
        end

        // Check Ready Logic
        if (ready != 1'b0) begin
            $display("[kernel_mem]: Error encountered with ready signal");
            j = j + 1;
        end

        // Test write enable
        #1;
        if (out != 0) begin
            $display("[kernel_mem]: Error encountered with write_en. Still writing to output kernel");
            j = j + 1;
        end

        // Check Ready
        #1 write_en = 1'b1;
        #9;     // FIXME: Not sure whether or not we can change this to be kernel_size * kernel_size later

        if (ready != 1'b1) begin
            $display("[kernel_mem]: Error encountered with ready signal. Waited (KERNEL_SIZE * KERNEL_SIZE) amount of time, yet no ready signal");
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

        // FIXME: Issue with this test not producing what we expect
        for (i = 1; i < (KERNEL_SIZE * KERNEL_SIZE) + 1; i = i + 1) begin
            kernel_in = i;
            #1;
        end

        // output should be 9, 8, 7, 6, 5, 4, 3, 2, 1
        // 000000001 000000010 000000011 000000100 000000101 000000110 000000111 000001000 000001001
        // MSB                                                                                   LSB

        $display("[kernel_mem]: Output from kernel_mem: %b", out);    // TODO: Should find better way of doing this later on
        



        if (j == 0) begin
            $display("[kernel_mem]: All tests for kernel_mem pass!");
        end
        
        $finish;
    end

    // Clock
    always #0.5 clk <= ~clk;
endmodule

`default_nettype wire