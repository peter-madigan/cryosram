`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/19/2019 10:20:21 AM
// Design Name: 
// Module Name: WriteCycle_tb
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
module WriteCycle_tb;
        reg clk_in; // Internal clk (100MHz)
        reg reset_in; // Global reset (active low)
        reg start_in; // Single tick pulse from button
        reg [8:0] a_in; // 9-bit read address (from fpga)
        reg [7:0] q_in; // 8-bit read value (from SRAM)
        wire clk_out; // Clk for SRAM
        wire cen_out; // Chip enable for SRAM
        wire wen_out; // Bitmask enable for SRAM
        wire [8:0] a_out; // 9-bit read address (for SRAM)
        wire [7:0] q_out; // 8-bit read value (for fpga)
        wire writing;
    parameter DELAY_CYCLES = 'd4;
    WriteCycle #(.DELAY(DELAY_CYCLES)) write_cycle (
        .clk_in(clk_in),
        .reset_in(reset_in),
        .start_in(start_in),
        .a_in(a_in),
        .q_in(q_in),
        .clk_out(clk_out),
        .cen_out(cen_out),
        .wen_out(wen_out),
        .a_out(a_out),
        .q_out(q_out),
        .writing(writing)
        );
    
    parameter PERIOD = 10;
    always begin
        clk_in = 1;
        #(PERIOD/2) clk_in = 0;
        #(PERIOD/2);
    end
    initial begin
        reset_in = 0;
        start_in = 0;
        a_in = {0,'hab};
        q_in = 'hcd;
        #(PERIOD*10) reset_in = 1;
        #(PERIOD*10) start_in = 1;
        #(PERIOD) start_in = 0;
    end
endmodule
