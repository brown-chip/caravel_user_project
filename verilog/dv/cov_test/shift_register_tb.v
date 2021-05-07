`default_nettype none

`timescale 1 ns / 1 ps

`include "uprj_netlists.v"
`include "caravel_netlists.v"

module shift_register_tb();
    // Parameters
    parameter BITS = 9;
    parameter KERNEL_SIZE = 3;
    parameter IMG_LENGTH = 16;

    // Input Output
    reg clk, reset, write_en;
    reg [BITS-1:0] serial_img_in;
    wire ready;
    wire [KERNEL_SIZE*KERNEL_SIZE*BITS-1:0] out;

    // Counter
    integer count;
    integer i;

    // Declaration of module
    shift_register uut(clk, reset, write_en, serial_img_in, ready, out);

    // Begin Testbench
    initial begin
        // Set initial conditions
        #0 clk = 1'b1;
        #0 reset = 1'b0;
        #0 write_en = 1'b0;
        #0 serial_img_in = 0;
        count = 0;

        // Test reset
        #1 reset = 1'b1;
        #1 reset = 1'b0;

        if (out != 0) begin
            $display("[shift register]: Reset error encountered");
            count = count + 1;
        end

        // Test write_en
        #1 serial_img_in = BITS'd1;
        #1;

        if (out != 0) begin
            $display("[shift register]: write_en error, writes when disabled");
            count = count + 1;
        end

        // Test ready logic
        #1 write_en = 1'b1;
        #(IMG_LENGTH * KERNEL_SIZE - 1 * KERNEL_SIZE);
        
        if (ready != 0) begin
            $display("[shift register]: ready not available when it should be available");
        end

        // Quick reset
        #1; 
        write_en = 1'b0;
        reset = 1'b1;
        serial_img_in = 0;

        #1 reset = 1'b0;

        // normal / general test
        #1 write_en = 1'b1;

        for (i = 0; i < IMG_LENGTH * KERNEL_SIZE - 1 * KERNEL_SIZE; i = i + 1) begin
            serial_img_in = i;
            #1;
        end

        // Check to see if output is correct at all
        $display("[shift register]: output, %b", out);  // TODO: Check if this is correct at all

        // I believe it shoud be something like 1, 2, 3, 
        // img_length + 1, img_length + 2, img_length + 3
        // img_length * 2 + 1,img_length * 2 + 2,img_length * 2 + 3

        // Print out if no errors
        if (count == 0) begin
            $display("[shift register]: all tests pass!");
        end

        $finish;        
    end

    // Clock
    always #0.5 clk <= ~clk;

endmodule

`default_nettype wire