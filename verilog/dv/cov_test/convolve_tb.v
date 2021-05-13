`default_nettype none

`timescale 1 ns / 1 ps

`include "uprj_netlists.v"
`include "caravel_netlists.v"


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

    localparam PERIOD = 20;
    reg clock;
    reg start0;
    wire done0;

	initial begin
		clock = 0;
    end

    always #(PERIOD/2) clock <= (clock === 1'b0);

    convolve_runner #(
        .BITS(9),
        .KERNEL_SIZE(3),
        .IMG_LENGTH(16),
        .IMG_NAME("img1.hex"),
        .PERIOD(PERIOD)
    ) U1 (
        .clock(clock),
        .start(start0),
        .done(done0)
    );

    initial begin
		#20
        start0 = 1;
        wait(done0);
        $finish;
	end
endmodule


module convolve_runner #(
    parameter BITS = 9,
    parameter KERNEL_SIZE = 3,
    parameter IMG_LENGTH = 16,
    parameter IMG_SIZE = 265,
    parameter IMG_NAME = "img1.hex",
    parameter PERIOD = 20
)
(
    input wire clock,
    input wire start,
    output reg done
);
    reg reset;
    reg [BITS-1:0] img_input;
    reg [BITS-1:0] kernel_in;
    wire [BITS-1:0] img_output;

    reg kernel_write_en, img_write_en;
    wire output_valid;

    convolve #(
        .BITS(BITS),
        .KERNEL_SIZE(KERNEL_SIZE),
        .IMG_LENGTH(IMG_LENGTH)
    ) UUT (
        .clk(clock),
        .reset(reset),
        .img_input(img_input),
        .kernel_in(kernel_in),
        .kernel_write_en(kernel_write_en),
        .shift_write_en(img_write_en),
        .output_valid(output_valid),
        .img_output(img_output)
    );

    // image memory
    
	reg [7:0] memory [0:IMG_SIZE-2];

	initial begin
		$display("Reading %s",  IMG_NAME);
		$readmemh(IMG_NAME, memory);
		$display("%s loaded into memory", IMG_NAME);
	end

    reg [BITS-1:0] kernel_arr [8:0];
    integer i;
    initial begin
        for (i = 0; i < 9; i = i + 1) begin
            kernel_arr[i] = 0;
            if (i == 4) kernel_arr[i] = 1;
        end
    end

	initial begin
        done = 0;
        wait(start == 1'd1);
        kernel_write_en = 0;
        img_write_en = 0;
        reset = 1;
        #PERIOD;
        reset = 0;
        #PERIOD;
        kernel_write_en = 1;
        $display("[Convolve]: begin testing");
        // load in the kernel
        for (i = 0; i < 9; i = i + 1) begin
            kernel_in = kernel_arr[i];
            if (UUT.kernel_mem.ready) begin
                $display("[Convolve]: kernel become ready too soon");
            end
            #PERIOD;
        end
        kernel_write_en = 0;

        if (!UUT.kernel_mem.ready) begin
            $display("[Convolve]: kernel is not ready");
        end

        for (i = 0; i < 9; i = i + 1) begin
            if (UUT.kernel_mem.out[BITS*i +: BITS] != kernel_arr[i]) begin
                $display("[Convolve]: kernel output is incorrect");
            end
        end
        #PERIOD;
        $display("[Convolve]: kernel loaded");

        // load in the image input from SPI flash
        img_write_en = 1;
        for (i = 0; i < IMG_SIZE; i = i + 1) begin
            img_input = memory[i];

            if (output_valid) begin
                $display("[Convolve]: Received %h", img_output);
            end
            #PERIOD;
        end
        img_write_en = 0;
        #PERIOD;

        for (i = 0; i < 128; i = i + 1) begin
            if (output_valid) begin
                $display("[Convolve]: Received %h", img_output);
            end
            #PERIOD;
        end

        done = 1;
	end

endmodule

`default_nettype wire