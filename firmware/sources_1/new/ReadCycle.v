`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
// 
// Create Date: 02/15/2019 10:58:21 AM
// Design Name: 
// Module Name: ReadCycle
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module ReadCycle (
    input [7:0] clk_factor, // delay period between actions (in clk_in ticks)
    input [7:0] read_delay, // delay between CEN go high and latch read bits
    input clk_in, // Internal clk (100MHz)
    input reset_in, // Global reset (active low)
    input start_in, // Single tick pulse from button
    input [8:0] a_in, // 9-bit read address (from fpga)
    input [7:0] q_in, // 8-bit read value (from SRAM)
    output clk_out, // Clk for SRAM
    output cen_out, // Chip enable for SRAM
    output wen_out, // Bitmask enable for SRAM
    output [8:0] a_out, // 9-bit read address (for SRAM)
    output [7:0] q_out, // 8-bit read value (for fpga)
    output reading // high if currently reading from SRAM
    );
    // Register inputs
    //
    reg reset = 1'b1;
    reg start = 1'b0;
    always @ (posedge clk_in) begin
        reset = reset_in;
        start = start_in;
    end
    
    // Counter for delay
    reg [7:0] counter = 8'b0;
    // Cycle running
    reg cycle = 1'b0;
    // internal registers for sending to sram
    reg clk = 1'b1;
    reg cen = 1'b1;
    reg wen = 1'b1;
    reg [8:0] a = 9'hfff;
    reg [7:0] q = 8'hff;
    always @ (posedge clk_in or posedge reset) begin
        // reset
        if (reset) begin
            counter <= 'd0;
            cycle <= 1'b0;
            clk <= 1'b1;
            cen <= 1'b1;
            wen <= 1'b1;
            a = 9'hfff;
            q = 8'hff;
        end
        else
        // start cycle
        if (~cycle & start) begin
            counter <= 1'b0;
            cycle <= 1'b1;
        end
        else
        // inside of cycle
        if (cycle & counter == 0) begin
            clk <= 1'b0;
            counter <= counter + 1;
        end
        else
        if (cycle & counter == 1) begin
            cen <= 1'b0;
            wen <= 1'b1;
            a <= a_in;
            counter <= counter + 1;
        end
        else
        if (cycle & counter == 2*clk_factor) begin
            clk <= 1'b1;
            counter <= counter + 1;
        end
        else
        if (cycle & counter == 4*clk_factor-1) begin
            cen <= 1'b1;
            wen <= 1'b1;
            q <= q_in;
            counter <= counter + 1;
        end
        else
        // add a few tick delay to account for level translator / chip loading
        if (cycle & (counter <= 4*clk_factor - 1 + read_delay) ) begin
            q <= q_in;
            counter <= counter + 1;
        end
        else
        // end of cycle
        if (cycle & counter >= 4*clk_factor) begin
            cycle <= 1'b0;
            counter <= 0;
            clk <= 1'b1;
            cen <= 1'b1;
            wen <= 1'b1;
            a <= 9'hfff;
        end
        // always tick counter
        else begin
            counter <= counter + 1;
        end     
     end
    
    // Output
    assign clk_out = clk;
    assign cen_out = cen;
    assign wen_out = wen;
    assign a_out = a;
    assign q_out = q;
    assign reading = cycle;
endmodule
