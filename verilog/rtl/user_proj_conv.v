// SPDX-FileCopyrightText: 2020 Efabless Corporation
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
// SPDX-License-Identifier: Apache-2.0

`default_nettype none
/*
 *-------------------------------------------------------------
 *
 * user_proj_example
 *
 * This is an example of a (trivially simple) user project,
 * showing how the user project can connect to the logic
 * analyzer, the wishbone bus, and the I/O pads.
 *
 * This project generates an integer count, which is output
 * on the user area GPIO pads (digital output only).  The
 * wishbone connection allows the project to be controlled
 * (start and stop) from the management SoC program.
 *
 * See the testbenches in directory "mprj_counter" for the
 * example programs that drive this user project.  The three
 * testbenches are "io_ports", "la_test1", and "la_test2".
 *
 *-------------------------------------------------------------
 */

module user_proj_conv #(
    parameter BITS = 9
)(
`ifdef USE_POWER_PINS
    inout vdda1,	// User area 1 3.3V supply
    inout vdda2,	// User area 2 3.3V supply
    inout vssa1,	// User area 1 analog ground
    inout vssa2,	// User area 2 analog ground
    inout vccd1,	// User area 1 1.8V supply
    inout vccd2,	// User area 2 1.8v supply
    inout vssd1,	// User area 1 digital ground
    inout vssd2,	// User area 2 digital ground
`endif

    // Wishbone Slave ports (WB MI A)
    input wb_clk_i,
    input wb_rst_i,
    input wbs_stb_i,
    input wbs_cyc_i,
    input wbs_we_i,
    input [3:0] wbs_sel_i,
    input [31:0] wbs_dat_i,
    input [31:0] wbs_adr_i,
    output wbs_ack_o,
    output [31:0] wbs_dat_o,

    // Logic Analyzer Signals
    input  [127:0] la_data_in,
    output [127:0] la_data_out,
    input  [127:0] la_oenb,

    // IOs
    input  [`MPRJ_IO_PADS-1:0] io_in,
    output [`MPRJ_IO_PADS-1:0] io_out,
    output [`MPRJ_IO_PADS-1:0] io_oeb,

    // IRQ
    output [2:0] irq
);
    wire clk;
    wire rst;

    wire [`MPRJ_IO_PADS-1:0] io_in;
    wire [`MPRJ_IO_PADS-1:0] io_out;
    wire [`MPRJ_IO_PADS-1:0] io_oeb;

    wire valid;

    // WB MI A
    assign valid = wbs_cyc_i && wbs_stb_i; 
    assign wbs_dat_o = 0;   // Unused
    assign wbs_ack_o = 0;   // Unused

    // IRQ
    assign irq = 3'b000;	// Unused

    // LA
    assign la_data_out = 0; // Unused

    // Assuming LA probes [65:64] are for controlling the count clk & reset  
    assign clk = (~la_oenb[64]) ? la_data_in[64]: wb_clk_i;
    assign rst = (~la_oenb[65]) ? la_data_in[65]: wb_rst_i;

    wire img_write_en;
    wire kernel_write_en;
    wire [BITS-1:0] img_input;
    wire [BITS-1:0] kernel_in;
    wire [BITS-1:0] img_output;
    
    assign img_write_en = io_in[0];
    assign kernel_write_en = io_in[1];
    assign img_input = io_in[BITS+1:2];
    assign kernel_in = io_in[2*BITS+1:BITS+2];

    assign io_out[3*BITS+1:2*BITS+2] = img_output;
    assign io_out[2*BITS+1:0] = 0;
    assign io_out[`MPRJ_IO_PADS-1:3*BITS+2] = 0;

    assign io_oeb[2*BITS+1:0] = 0;
    assign io_oeb[`MPRJ_IO_PADS-1:2*BITS+2] = {(`MPRJ_IO_PADS-2*BITS-2){rst}};

    convolve #(
        .BITS(BITS)
    ) convolve (
        .clk(clk),
        .reset(rst),
        .img_input(img_input),
        .kernel_in(kernel_in),
        .kernel_write_en(kernel_write_en),
        .shift_write_en(img_write_en),
        .img_output(img_output)
    );

endmodule

module convolve #(
    parameter BITS = 9,
    parameter KERNEL_SIZE = 3,
    parameter IMG_LENGTH = 16
)(
    input clk,
    input reset,
    input [BITS-1:0] img_input,
    input [BITS-1:0] kernel_in,
    input kernel_write_en,
    input shift_write_en,
    output output_valid,
    output [BITS-1:0] img_output
);

    wire [KERNEL_SIZE*KERNEL_SIZE*BITS-1:0] kernel_output;
    wire [KERNEL_SIZE*KERNEL_SIZE*BITS-1:0] shift_reg_output;

    wire kernel_ready, shift_ready;
    wire mult_out_valid;
    wire [BITS-1:0] mult_output;

    shift_register #(
        .BITS(BITS),
        .KERNEL_SIZE(KERNEL_SIZE),
        .IMG_LENGTH(IMG_LENGTH)
    ) shift_register (
        .clk(clk),
        .reset(reset),
        .write_en(shift_write_en),
        .serial_img_in(img_input),
        .ready(shift_ready),
        .out(shift_reg_output)
    );

    kernel_mem #(
        .BITS(BITS),
        .KERNEL_SIZE(KERNEL_SIZE)
    ) kernel_mem (
        .clk(clk),
        .reset(reset),
        .write_en(kernel_write_en),
        .kernel_in(kernel_in),
        .ready(kernel_ready),
        .out(kernel_output)
    );

    multiplier #(
        .BITS(BITS),
        .KERNEL_SIZE(KERNEL_SIZE)
    ) multiplier (
        .clk(clk),
        .out_en(shift_ready & kernel_ready),
        .shift_in(shift_reg_output),
        .kernel_in(kernel_output),
        .pixel_out(mult_output),
        .output_valid(mult_out_valid)
    );

    output_filter #(
        .BITS(BITS),
        .IMG_LENGTH(IMG_LENGTH),
        .KERNEL_SIZE(KERNEL_SIZE)
    ) output_filter (
        .clk(clk),
        .reset(reset),
        .input_valid(mult_out_valid),
        .pixel_in(mult_output),
        .pixel_out(img_output),
        .output_valid(output_valid)
    );

endmodule

module shift_register #(
    parameter BITS = 9,
    parameter KERNEL_SIZE = 3,
    parameter IMG_LENGTH = 16
)(
    input wire clk,
    input wire reset,
    input wire write_en,
    input wire [BITS-1:0] serial_img_in,
    output wire ready,
    output reg [KERNEL_SIZE*KERNEL_SIZE*BITS-1:0] out
);
    // Intermediate shift register declaration
    // Dependent on img size, but I believe we need two full rows + 3 values
    reg [BITS-1:0] arr [(IMG_LENGTH * (KERNEL_SIZE - 1) + KERNEL_SIZE)-1:0];
    reg [31:0] counter;
    integer i,j,k,m;
    
    always @(posedge clk) begin
        // RESET Logic
        if (reset) begin
            for (m = 0; m < (IMG_LENGTH * (KERNEL_SIZE - 1) + KERNEL_SIZE); m = m + 1) begin
                arr[m] <= 0;
            end
            counter <= 0;
        end else begin
            // Rest of logic

            // shift everything over from high index -> low index
            for (i = 0; i < (IMG_LENGTH * (KERNEL_SIZE - 1) + KERNEL_SIZE); i = i + 1) begin
                arr[i] <= arr[i + 1];
            end

            // push in the data
            if (write_en) begin
                // Write new serial_img data into highest index in shift reg
                arr[(IMG_LENGTH * (KERNEL_SIZE - 1) + KERNEL_SIZE)-1] <= serial_img_in;

                // Counter Logic to handle ready
                if (counter == (IMG_LENGTH * (KERNEL_SIZE - 1) + KERNEL_SIZE)) begin
                    counter <= counter;
                end else begin
                    counter <= counter + 1;
                end
            end else begin
                // Get rid of inferred latch with writing 0 if not write_en
                arr[(IMG_LENGTH * (KERNEL_SIZE - 1) + KERNEL_SIZE)-1] <= 0;
                counter <= 0;
            end
        end      
    end

    // Determine Output Comb logic
    always @* begin
        for (j = 0; j < KERNEL_SIZE; j = j + 1) begin
            for (k = 0; k < KERNEL_SIZE; k = k + 1) begin
                out[(j*KERNEL_SIZE+k)*BITS +: BITS] = arr[j*IMG_LENGTH + k];
            end
        end
    end

    // If counter is full, then shift register is completely full and can start doing convolution 
    assign ready = (counter == (IMG_LENGTH * (KERNEL_SIZE - 1) + KERNEL_SIZE));
endmodule

module kernel_mem #(
    parameter BITS = 9,
    parameter KERNEL_SIZE = 3
)(
    input clk,
    input reset,
    input write_en,
    input signed [BITS-1:0] kernel_in,
    output ready,
    output signed [KERNEL_SIZE*KERNEL_SIZE*BITS-1:0] out
);  
    // Note: We use synchronous active high resets in the same way source code does
    // Note: We also assume that we get streamed one kernel value per clk cycle which
    //       may be wrong, but we will stick with it for now 
    // Declaration of net types for I/O 
    wire clk;
    wire reset;
    wire write_en;
    wire signed [BITS-1:0] kernel_in;
    wire ready;
    reg signed [(BITS-1):0] arr [(KERNEL_SIZE*KERNEL_SIZE - 1):0];
    reg signed [KERNEL_SIZE*KERNEL_SIZE*BITS-1:0] out;

    // Intermediate values
    integer i, j, k;
    reg [3:0] counter; // TODO: Change this to be able to work with kernel size

    always @ (posedge clk) begin
        if (reset) begin
            // FIXME: Right now, it outputs a 0 for everything but we may want to
            //        fix later on to make the kernel be 1 in the middle and 0 everywhere else

            // Resets output values all to 0
            for (i = 0; i < KERNEL_SIZE*KERNEL_SIZE; i = i + 1) begin
                arr[i] <= 0;
            end

            // reset the counter
            counter <= 0;

        end else begin
            // Assumes that the write_en is enabled continuously but shouldn't matter
            if (write_en && counter < KERNEL_SIZE*KERNEL_SIZE) begin
                arr[counter] = kernel_in;
                counter <= counter + 4'd1;
            end else begin
                counter <= counter;
            end
        end
    end

    // Combinational Logic
    assign ready = (counter == KERNEL_SIZE*KERNEL_SIZE);

    always @* begin
        // We now flip the kernel so that we can compute convolution
        k = (KERNEL_SIZE * KERNEL_SIZE) - 1;  // k serves as the internal array address
        for (j = 0; j < (KERNEL_SIZE * KERNEL_SIZE); j = j + 1) begin
            out[BITS*j +: BITS] = arr[k];
            k = k - 1;
        end
    end


endmodule

module output_filter #(
    parameter BITS = 9,
    parameter IMG_LENGTH = 16,
    parameter KERNEL_SIZE = 3
)(
    input clk,
    input reset,
    input signed [BITS-1:0] pixel_in,
    input input_valid,
    output reg signed [BITS-1:0] pixel_out,
    output reg output_valid
);
    wire bit_valid;
    integer cnt;

    assign bit_valid = input_valid & (cnt <= IMG_LENGTH - KERNEL_SIZE);

    always @(posedge clk) begin
        if (reset || !input_valid || cnt == IMG_LENGTH - 1) begin
            cnt <= 0;
        end else begin
            cnt <= cnt + 1;
        end
        
        output_valid <= bit_valid;
        pixel_out <= pixel_in & {(BITS){bit_valid}};
    end
endmodule

module multiplier #(
    parameter BITS = 9,
    parameter KERNEL_SIZE = 3
)(
    input clk,
    input out_en,
    input [KERNEL_SIZE*KERNEL_SIZE*BITS-1:0] shift_in,
    input signed [KERNEL_SIZE*KERNEL_SIZE*BITS-1:0] kernel_in,  // FIXME: 
    output reg signed [BITS-1:0] pixel_out,
    output reg output_valid
);

    // FIXME: can actually be smaller than this
    reg signed [BITS*3:0] accum_out;
    integer i;

    always @(posedge clk) begin
        output_valid <= 1;
        if (!out_en) begin
            pixel_out <= 0;
            output_valid <= 0;
        end else if (|accum_out[BITS*3 - 1:BITS] & (accum_out[BITS*3] == 0)) begin
            // Clip the value at maximum if the output overflow.
            pixel_out <= {1'd0, {(BITS-1){1'd1}}};
        end else if ((~&accum_out[BITS*3 - 1:BITS]) & (accum_out[BITS*3] == 1'b1)) begin
            // Clip values at minimum
            pixel_out <= {1'd1, {(BITS-1){1'd0}}};
        end else begin
            // Regular case
            pixel_out <= accum_out[BITS-1:0];
        end 
    end

    // optimize the multiplication (maybe clocked?)
    always @* begin
        accum_out = 0;
        for (i = 0; i < KERNEL_SIZE * KERNEL_SIZE; i = i + 1) begin
            // FIXME: this is too long, fix this
            accum_out = accum_out +
                $signed({{(BITS*2){shift_in[(i+1)*BITS - 1]}}, shift_in[i*BITS +: BITS]}) *
                $signed({{(BITS*2){kernel_in[(i+1)*BITS - 1]}}, kernel_in[i*BITS +: BITS]});
        end
    end

endmodule

`default_nettype wire