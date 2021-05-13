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

    localparam BITS = 9;
    localparam KERNEL_SIZE = 3;
    localparam IMG_LENGTH = 5;
    localparam IMG_NAME = "img1.hex";
    localparam period = 20;
    
    reg clock, reset;
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
    
	reg [7:0] memory [255:0];

	initial begin
		$display("Reading %s",  IMG_NAME);
		$readmemh(IMG_NAME, memory);
		$display("%s loaded into memory", IMG_NAME);
	end

    always #(period/2) clock <= (clock === 1'b0);

	initial begin
		clock = 0;
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
        kernel_write_en = 0;
        img_write_en = 0;
        reset = 1;
        #period;
        reset = 0;
        #period;
        kernel_write_en = 1;
        // load in the kernel
        for (i = 0; i < 9; i = i + 1) begin
            kernel_in = kernel_arr[i];
            if (UUT.kernel_mem.ready) begin
                $display("[Convolve]: kernel become ready too soon");
            end
            #period;
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
        #period;

        // load in the image input from SPI flash
        img_write_en = 1;
        for (i = 0; i < 32; i = i + 1) begin
            img_input = memory[i];

            if (output_valid) begin
                $display("[Convolve]: Received %h", img_output);
            end
            #period;
        end
        img_write_en = 0;
        #period;

        for (i = 0; i < 128; i = i + 1) begin
            if (output_valid) begin
                $display("[Convolve]: Received %h", img_output);
            end
            #period;
        end

        $finish;
	end
endmodule
