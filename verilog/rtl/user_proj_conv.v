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

    wire [31:0] rdata; 
    wire [31:0] wdata;
    wire [BITS-1:0] count;

    wire valid;
    wire [3:0] wstrb;
    wire [31:0] la_write;

    // WB MI A
    assign valid = wbs_cyc_i && wbs_stb_i; 
    assign wstrb = wbs_sel_i & {4{wbs_we_i}};
    assign wbs_dat_o = rdata;
    assign wdata = wbs_dat_i;

    // IO
    // assign io_out = count;
    // assign io_oeb = {(`MPRJ_IO_PADS-1){rst}};

    // IRQ
    assign irq = 3'b000;	// Unused

    // LA
    assign la_data_out = {{(127-BITS){1'b0}}, count};
    // Assuming LA probes [63:32] are for controlling the count register  
    assign la_write = ~la_oenb[63:32] & ~{BITS{valid}};
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

    assign io_oeb[2*BITS+1:0] = 0;
    assign io_oeb[`MPRJ_IO_PADS-1:2*BITS+2] = {(`MPRJ_IO_PADS-2*BITS-2){rst}};

    convolve #(
        .BITS(BITS)
    ) convolve(
        .clk(clk),
        .reset(rst),
        .img_input(img_input),
        .kernel_in(kernel_in),
        .kernel_write_en(kernel_write_en),
        .shift_write_en(img_write_en),
        .img_output(img_output)
        // .ready(wbs_ack_o),
        // .valid(valid),
        // .rdata(rdata),
        // .wdata(wbs_dat_i),
        // .wstrb(wstrb),
        // .la_write(la_write),
        // .la_input(la_data_in[63:32]),
        // .count(count)
    );

endmodule

module convolve #(
    parameter BITS = 9,
    parameter KERNEL_SIZE = 3
)(
    input clk,
    input reset,
    input [BITS-1:0] img_input,
    input [BITS-1:0] kernel_in,
    input kernel_write_en,
    input shift_write_en,
    output [BITS-1:0] img_output
    // input valid,
    // input [3:0] wstrb,
    // input [BITS-1:0] wdata,
    // input [BITS-1:0] la_write,
    // input [BITS-1:0] la_input,
    // output ready,
    // output [BITS-1:0] rdata,
    // output [BITS-1:0] count
);
    // reg ready;
    // reg [BITS-1:0] count;
    // reg [BITS-1:0] rdata;

    // always @(posedge clk) begin
    //     if (reset) begin
    //         count <= 0;
    //         ready <= 0;
    //     end else begin
    //         ready <= 1'b0;
    //         if (~|la_write) begin
    //             count <= count + 1;
    //         end
    //         if (valid && !ready) begin
    //             ready <= 1'b1;
    //             rdata <= count;
    //             if (wstrb[0]) count[7:0]   <= wdata[7:0];
    //             if (wstrb[1]) count[15:8]  <= wdata[15:8];
    //             if (wstrb[2]) count[23:16] <= wdata[23:16];
    //             if (wstrb[3]) count[31:24] <= wdata[31:24];
    //         end else if (|la_write) begin
    //             count <= la_write & la_input;
    //         end
    //     end
    // end

    wire [KERNEL_SIZE*KERNEL_SIZE*BITS-1:0] kernel_output;
    wire [KERNEL_SIZE*KERNEL_SIZE*BITS-1:0] shift_reg_output;

    wire kernel_ready, shift_ready;
    
    shift_register #(
        .BITS(BITS),
        .KERNEL_SIZE(KERNEL_SIZE)
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
        .pixel_out(img_output)
    );

endmodule

module shift_register #(
    parameter BITS = 9,
    parameter KERNEL_SIZE = 3,
    parameter IMG_LENGTH = 128
)(
    input clk,
    input reset,
    input write_en,
    input [BITS-1:0] serial_img_in,
    output ready,
    output [KERNEL_SIZE*KERNEL_SIZE*BITS - 1:0] out
);
    wire clk;
    wire reset;
    wire write_en;
    wire [BITS-1:0] serial_img_in;
    wire ready;
    reg [KERNEL_SIZE*KERNEL_SIZE*BITS - 1:0] out;

    // Intermediate shift register declaration
    // Dependent on img size, but I believe we need two full rows + 3 values
    reg [BITS-1:0] arr [(IMG_LENGTH * (KERNEL_SIZE - 1) + KERNEL_SIZE):0];
    reg [31:0] counter;         // TODO: need to figure out how many bits we actually need
    integer i, j, k, l, m;
    
    always @(posedge clk) begin
        // RESET Logic
        if (reset) begin
            for (m = 0; m < IMG_LENGTH * (KERNEL_SIZE - 1); m = m + 1) begin
                arr[m] <= 0;
            end
            counter <= 0;
        end else begin
            // Rest of logic

            // shift everything
            for (i = 0; i < (IMG_LENGTH * (KERNEL_SIZE - 1) + KERNEL_SIZE) - 1; i = i + 1) begin
                arr[i] <= arr[i + 1];
            end

            // push in the data
            if (write_en) begin
                arr[(IMG_LENGTH * (KERNEL_SIZE - 1) + KERNEL_SIZE)] <= serial_img_in;

                // Counter Logic
                if (counter == (IMG_LENGTH * (KERNEL_SIZE - 1) + KERNEL_SIZE + 1)) begin
                    counter = counter;
                end else begin
                    counter <= counter + 1;
                end
            end
        end      
    end

    // Determine Output Bits that we need
    always @* begin
        l = 0;
        for (j = 0; j < (IMG_LENGTH * KERNEL_SIZE); j = j + IMG_LENGTH) begin
            for (k = 0; k < KERNEL_SIZE; k = k + 1) begin
                // out[(j*KERNEL_SIZE+k+1)*BITS-1:(j*KERNEL_SIZE+k)*BITS] = arr[j*IMG_LENGTH + k];

                out[l+(BITS - 1):l] = arr[j + k];
                l = l + BITS;
            end
        end
    end

    // If counter is full
    assign ready = (counter == (IMG_LENGTH * (KERNEL_SIZE - 1) + KERNEL_SIZE + 1));
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

    // FIXME: We need to flip the kernel for image convolution

    // Note: We use synchronous active high resets in the same way source code does
    // Note: We also assume that we get streamed one kernel value per clk cycle which
    //       may be wrong, but we will stick with it for now 
    // Declaration of net types for I/O 
    wire clk;
    wire reset;
    wire write_en;
    wire signed [BITS-1:0] kernel_in;
    reg ready;
    reg signed [KERNEL_SIZE*KERNEL_SIZE*BITS-1:0] out;

    // Intermediate values
    integer i;
    reg [3:0] counter; // TODO: Change this to be able to work with kernel size

    always @ (posedge clk) begin
        if (reset) begin
            // FIXME: Right now, it outputs a 0 for everything but we may want to
            //        fix later on to make the kernel be 1 in the middle and 0 everywhere else

            // Resets output values all to 0
            out[KERNEL_SIZE*KERNEL_SIZE*BITS-1:0] <= 0;

            // reset the counter
            counter <= 0;

        end else begin
            // Assumes that the write_en is enabled continuously but shouldn't matter
            if (write_en && counter < 9) begin
                out[(counter+1)*BITS-1:counter*BITS] = kernel_in;
                counter <= counter + 1;
            end else begin
                counter <= counter;
            end
        end
    end

    assign ready = (counter == 4'd9);
endmodule

module multiplier #(
    parameter BITS = 9,
    parameter KERNEL_SIZE = 3
)(
    input clk,
    input out_en,
    input [KERNEL_SIZE*KERNEL_SIZE*BITS-1:0] shift_in,
    input signed [KERNEL_SIZE*KERNEL_SIZE*BITS-1:0] kernel_in,
    output reg signed [BITS-1:0] pixel_out
);

    // FIXME: can actually be smaller than this
    wire [BITS*3:0] accum_out;
    integer i;

    always @(posedge clk) begin
        if (!out_en) begin
            pixel_out <= 0;
        end else if (|accum_out[BITS*3 - 1:BITS] & (accum_out[BITS*3] == 0)) begin
            // Clip the value at maximum if the output overflow.
            pixel_out <= {0, {(BITS-1){1}}};
        end else if ((~&accum_out[BITS*3 - 1:BITS]) & (accum_out[BITS*3] == 1'b1)) begin
            // Clip values at minimum
            pixel_out <= {1, {(BITS-1){0}}};
        end else begin
            // Regular case
            pixel_out <= accum_out[BITS-1:0];
        end 
    end

    // optimize the multiplication (maybe clocked?)
    always @* begin
        accum_out = 0;
        for (i = 0; i < KERNEL_SIZE * KERNEL_SIZE; i = i + 1) begin
            accum_out = accum_out + shift_in[(i+1)*BITS-1:i*BITS] * kernel_in[(i+1)*BITS-1:i*BITS];
        end
    end

endmodule

`default_nettype wire