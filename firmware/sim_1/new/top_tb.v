`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/14/2019 04:56:56 PM
// Design Name: 
// Module Name: top_tb
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

module top_tb;
    parameter DEBOUNCE_DELAY = 'd1;
    reg clk_in;
    reg btnT_in;
    reg btnC_in;
    reg btnL_in;
    reg btnR_in;
    reg btnD_in;
    reg [15:0] sw_in;
    wire [15:0] led_out;
    wire [6:0] segment_out;
    wire dp_out;
    wire [3:0] digit_out;
    wire [7:0] JA_out;
    wire [7:0] JB_out;
    reg [7:0] JC_in;
    wire [7:0] JXADC_out;
    // synthesis translate_off
    wire [27:0] debug;
    // synthesis translate_on
    
    top #(.DEBOUNCE_DELAY(DEBOUNCE_DELAY)) top_sim(
        .clk(clk_in),
        .btnT(btnT_in),
        .btnC(btnC_in),
        .btnL(btnL_in),
        .btnR(btnR_in),
        .btnD(btnD_in),
        .sw(sw_in),
        .led(led_out),
        .segment(segment_out),
        .dp(dp_out),
        .digit(digit_out),
        .JA(JA_out),
        .JB(JB_out),
        .JC(JC_in),
        .JXADC(JXADC_out)
        // synthesis translate_off
        , .debug(debug)
        // synthesis translate_on
        );

    parameter PERIOD = 10;
    always begin
        clk_in = 1'b1;
        #(PERIOD/2) clk_in = 1'b0;
        #(PERIOD/2);
    end
    initial begin
        // start in reset
        clk_in = 1'b1;
        btnT_in = 1'b1;
        btnC_in = 1'b0;
        btnL_in = 1'b0;
        btnR_in = 1'b0;
        btnD_in = 1'b0;
        #(PERIOD*10) btnT_in = 1'b0;
        // set read/write addr
        #(PERIOD*10) sw_in = 'h00cd;
        #(PERIOD*10) btnD_in = 1'b1;
        #(PERIOD*10) btnD_in = 1'b0;
        // set write value
        #(PERIOD*10) sw_in = 'h00ef;
        #(PERIOD*10) btnC_in = 1'b1;
        #(PERIOD*10) btnC_in = 1'b0;
        // set clk_factor value
        #(PERIOD*10) sw_in = 'h0002;
        #(PERIOD*10) sw_in[14] = 1'b1;
        #(PERIOD*10) sw_in[14] = 1'b0;
        // swap display
        #(PERIOD*10) sw_in[15] = 1'b1;
        #(PERIOD*100);
        #(PERIOD*10) sw_in[15] = 1'b0;
        // write value
        #(PERIOD*10) btnR_in = 1'b1;
        #(PERIOD*10) btnR_in = 1'b0;
        #(PERIOD*100);
        // read value
        #(PERIOD*10) JC_in = 'hab;
        #(PERIOD*10) btnL_in = 1'b1;
        #(PERIOD*10) btnL_in = 1'b0;
        #(PERIOD*100);
        // final reset
        #(PERIOD*10) btnT_in = 1'b1;
        #(PERIOD*10) btnT_in = 1'b0;
        
        // test weird address bug
        // write to reg 256
        #(PERIOD*10) JC_in = 'hff;
        
        #(PERIOD) sw_in = 'h0080;
        #(PERIOD*10) btnC_in = 1'b1;
        #(PERIOD*50) btnC_in = 1'b0;
        #(PERIOD) sw_in = 'h00ff;
        #(PERIOD*10) btnD_in = 1'b1;
        #(PERIOD*50) btnD_in = 1'b0;
        #(PERIOD*10) btnR_in = 1'b1;
        #(PERIOD*50) btnR_in = 1'b0;
        // check that read is 'hff
        #(PERIOD*10) btnL_in = 1'b1;
        #(PERIOD*50) btnL_in = 1'b0;
        // write to reg 0
        #(PERIOD) sw_in = 'h0000;
        #(PERIOD*10) btnC_in = 1'b1;
        #(PERIOD*50) btnC_in = 1'b0;
        #(PERIOD) sw_in = 'h0000;
        #(PERIOD*10) btnD_in = 1'b1;
        #(PERIOD*50) btnD_in = 1'b0;
        #(PERIOD*10) btnR_in = 1'b1;
        #(PERIOD*50) btnR_in = 1'b0;
        // change back to reg 256
        #(PERIOD) sw_in = 'h0080;
        #(PERIOD*10) btnC_in = 1'b1;
        #(PERIOD*50) btnC_in = 1'b0;
        // perform a read
        #(PERIOD*10) btnL_in = 1'b1;
        #(PERIOD*50) btnL_in = 1'b0;
    end
endmodule
