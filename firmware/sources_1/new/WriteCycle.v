`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
// 
// Create Date: 02/15/2019 10:58:21 AM
// Design Name: 
// Module Name: WriteCycle
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


module WriteCycle  (
    input [7:0] clk_factor, // delay period between actions (in clk_in ticks)
    input clk_in, // Internal clk (100MHz)
    input reset_in, // Global reset
    input start_in, // Single tick pulse from button
    input [8:0] a_in, // 9-bit write address (from fpga)
    input [7:0] d_in, // 8-bit write value (from fpga)
    output clk_out, // Clk for SRAM
    output cen_out, // Chip enable for SRAM
    output wen_out, // Bitmask enable for SRAM
    output [8:0] a_out, // 9-bit write address (for SRAM)
    output [7:0] d_out, // 8-bit write value (for SRAM)
    output writing // high if writing to SRAM
    );
    // Register inputs
    //
    reg reset = 1;
    reg start = 0;
    always @ (posedge clk_in) begin
        reset = reset_in;
        start = start_in;
    end
    
    // Counter for delay
    reg [7:0] counter = 0;
    // Cycle running
    reg cycle = 0;
    reg clk = 1;
    reg cen = 1;
    reg wen = 1;
    reg [8:0] a = 'hfff;
    reg [7:0] d = 'hff;
    always @ (posedge clk_in or posedge reset) begin
        if (reset) begin
            cycle <= 0;
            counter <= 0;
            clk <= 1;
            cen <= 1;
            wen <= 1;
            a <= 'hfff;
            d <= 'hff;
        end
        else
        // start new cycle and reset counter
        if (~cycle & start) begin
            cycle <= 1'b1;
            counter <= 1'b0;
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
            wen <= 1'b0;
            a <= a_in;
    	    d <= d_in;
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
            a <= 'hfff;
            d <= 'hff;
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
    assign d_out = d;
    assign writing = cycle;
endmodule
