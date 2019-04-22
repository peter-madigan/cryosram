`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08/15/2017 02:34:58 PM
// Design Name: 
// Module Name: segnum
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

module segnum (
    input clk,
    input [3:0] number,
    output reg [6:0] seg = 0
    );
    
    parameter [6:0] p0 = 'b1000000;
    parameter [6:0] p1 = 'b1111001;
    parameter [6:0] p2 = 'b0100100;
    parameter [6:0] p3 = 'b0110000;
    parameter [6:0] p4 = 'b0011001;
    parameter [6:0] p5 = 'b0010010;
    parameter [6:0] p6 = 'b0000010;
    parameter [6:0] p7 = 'b1111000;
    parameter [6:0] p8 = 'b0000000;
    parameter [6:0] p9 = 'b0010000;
    parameter [6:0] pa = 'b0001000;
    parameter [6:0] pb = 'b0000011;
    parameter [6:0] pc = 'b1000110;
    parameter [6:0] pd = 'b0100001;
    parameter [6:0] pe = 'b0000110;
    parameter [6:0] pf = 'b0001110;
    parameter [6:0] pp = 'b1111101;
        
    always @ (posedge clk)
        case (number)
            'h0: seg <= p0;
            'h1: seg <= p1;
            'h2: seg <= p2;
            'h3: seg <= p3;
            'h4: seg <= p4;
            'h5: seg <= p5;
            'h6: seg <= p6;
            'h7: seg <= p7;
            'h8: seg <= p8;            
            'h9: seg <= p9;            
            'hA: seg <= pa;            
            'hB: seg <= pb;            
            'hC: seg <= pc;            
            'hD: seg <= pd;            
            'hE: seg <= pe;            
            'hF: seg <= pf;          
        endcase

        
endmodule
