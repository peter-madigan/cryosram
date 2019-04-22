`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08/14/2017 04:14:07 PM
// Design Name: 
// Module Name: counter
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
`timescale 1ns / 1ps


module display4(
    input clk100,
    output reg [3:0] digit = 0,  //digit 3 is leftmost (MSD), digit 1 is rightmost (LSD)
    output reg [6:0] segments = 'b111111, //7 segments: top,mid,bot and top_left/bot_left and same for right
    output reg period,
    input [15:0] number     //4 hex digits
    );



//
// well, verilog arithmetic is pretty good so let's just let it figure out the digits
//
wire [3:0] digit3 = number[15:12];
wire [3:0] digit2 = number[11:8];
wire [3:0] digit1 = number[7:4];
wire [3:0] digit0 = number[3:0];

//
// make a clock from the 100MHz clock that refreshes at around 60Hz or more.
// that means a period of at least 16ms.   with a 10ns period input clock,
// if you set up a register with N bits, the period is given by:
// T = 10ns * 2^{N+1}
// so we want 16ms = 10ns * 2^{N+1} solving for that gives 19.6 bits so we use 19
// to make it a little faster than 60Hz.  
//
// But, since we can only have one digit on at a time, we need to change the digits
// by 4 times this value.   that means we need to run the clock 4x faster, and use
// that slow clock to increment a 2-bit pointer and cycle through the 4 digits one at a time
//
reg [17:0] counter = 0;
//
// use negedge so we don't have race conditions later
//
always @ (negedge clk100) counter <= counter + 1; 
wire digit_clock = counter[17];
wire clock;
BUFG clkdbuf (.I(digit_clock),.O(clock));
reg [1:0] which_digit;
always @ (posedge clock) which_digit <= which_digit + 1;

wire [6:0] wseg0, wseg1, wseg2, wseg3;
segnum S0 ( .clk(clk100), .number(digit0), .seg(wseg0) );
segnum S1 ( .clk(clk100), .number(digit1), .seg(wseg1) );
segnum S2 ( .clk(clk100), .number(digit2), .seg(wseg2) );
segnum S3 ( .clk(clk100), .number(digit3), .seg(wseg3) );

always @ (posedge clock) begin
    period <= 1;       // turn it off for now
    case (which_digit)
        'h0: begin
                digit <= 'b1110;
                segments <= wseg0;
            end
        'h1: begin
                digit <= 'b1101;
                segments <= wseg1;
            end
        'h2: begin
                digit <= 'b1011;
                segments <= wseg2;
            end
        'h3: begin
                digit <= 'b0111;
                segments <= wseg3;
            end
      endcase
end 

endmodule
