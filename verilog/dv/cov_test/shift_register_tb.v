`timescale 1ns/1ps
`include "uprj_netlists.v"
`include "caravel_netlists.v"

module shift_register_tb();
    // Parameters
    parameter BITS = 9;
    parameter KERNEL_SIZE = 3;
    parameter IMG_LENGTH = 16;

    // Parsed Output
    reg [BITS-1:0] real_out [KERNEL_SIZE*KERNEL_SIZE-1:0];

    // Input Output
    reg clk, reset, write_en;
    reg [BITS-1:0] serial_img_in;
    wire ready;
    wire [KERNEL_SIZE*KERNEL_SIZE*BITS-1:0] out;

    // Counter
    integer count;
    integer i, j, k;

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
        #1 serial_img_in = 9'd1;
        #1;

        if (out != 0) begin
            $display("[shift register]: write_en error, writes when disabled");
            count = count + 1;
        end

        // Test ready logic
        #1 write_en = 1'b1;
        #(IMG_LENGTH * (KERNEL_SIZE - 1) + KERNEL_SIZE);
        
        if (ready != 1) begin
            $display("[shift register]: ready not available when it should be available");
            count = count + 1;
        end

        // Quick reset
        #1; 
        write_en = 1'b0;
        reset = 1'b1;
        serial_img_in = 0;

        #1 reset = 1'b0;

        // normal / general test
        #1 write_en = 1'b1;

        for (i = 0; i < IMG_LENGTH * (KERNEL_SIZE - 1) + KERNEL_SIZE; i = i + 1) begin
            serial_img_in = i;
            #1;
        end

        for (i = 0; i < KERNEL_SIZE; i = i + 1) begin
            for (j = 0; j < KERNEL_SIZE; j = j + 1) begin
                if (real_out[(i * KERNEL_SIZE) + j] != (i * IMG_LENGTH) + j) begin
                    $display("[shift register]: Error in Normal Test: Expected: %d , Got: %d", (i * IMG_LENGTH) + j, real_out[(i * KERNEL_SIZE) + j]);
                    count = count + 1;
                end 
            end
        end
        
        // Print out if no errors
        if (count == 0) begin
            $display("[shift register]: all tests pass!");
        end

        $finish;        
    end

    // Clock
    always #0.5 clk <= ~clk;

    // Assign to easily understand what is going on
    always @* begin
        k = 0;
        for (j = 0; j < KERNEL_SIZE*KERNEL_SIZE; j = j + 1) begin
            real_out[j] = out[BITS*k +: BITS];
            k = k + 1;
        end   
    end

endmodule