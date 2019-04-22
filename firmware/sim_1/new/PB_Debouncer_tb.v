`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/19/2019 10:38:15 AM
// Design Name: 
// Module Name: PB_Debouncer_tb
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


module PB_Debouncer_tb;
    reg clk;
    reg reset;
    reg PB;
    wire [7:0] debug;
    wire PB_state;
    wire PB_down;
    wire PB_up;
    parameter DELAY='d1;
    PB_Debouncer #(.DELAY(DELAY)) debounce (
        .i_clk(clk),
        .i_reset(reset),
        .i_PB(PB),
        .o_debug(debug),
        .o_PB_state(PB_state),
        .o_PB_down(PB_down),
        .o_PB_up(PB_up)
        );
    parameter PERIOD = 10;
    always begin
        clk = 1;
        #(PERIOD/2) clk = 0;
        #(PERIOD/2);
    end
    initial begin
        reset = 0;
        PB = 1;
        #(PERIOD*10) reset = 1;
        #(PERIOD*10) PB = 0;
        #(PERIOD*10) PB = 1;
    end 
endmodule
