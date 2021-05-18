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
    reg [BITS-1:0] easy_out [KERNEL_SIZE*KERNEL_SIZE-1:0];

    // Loop inputs
    integer i, j, k;

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
        #9;     

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

        for (i = 1; i < (KERNEL_SIZE * KERNEL_SIZE) + 1; i = i + 1) begin
            kernel_in = i;
            #1;
        end

        for (i = 0; i < KERNEL_SIZE*KERNEL_SIZE; i = i + 1) begin
            if (easy_out[i] != 9 - i) begin
               $display("[kernel_mem]: Normal Test: Expected %d, but got %d instead", 9-i, easy_out[i]);
               j = j + 1; 
            end
        end                                                                  

        if (j == 0) begin
            $display("[kernel_mem]: All tests for kernel_mem pass! 14/14");
        end
        
        $finish;
    end

    // Clock
    always #0.5 clk <= ~clk;

    // Reassign output to 9 bit intervals for ease of reading
    always @* begin
        for (k = 0; k < KERNEL_SIZE * KERNEL_SIZE; k = k + 1) begin
            easy_out[k] = out[k*BITS +: BITS];
        end        
    end
endmodule