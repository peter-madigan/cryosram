`timescale 1ns / 1ps
//
// basic serial protocol IO device driver
//
// CLKS_BER_BIT = ratio of internal clock to baud rate desired
// o_debug: lower 7 bits come from RX, upper from TX module
//          see uart_* for what bits are where

module SerialIO #(parameter CLKS_PER_BIT = 'd100) (
    input i_Clock,
    input i_Reset,
    
    input i_Rx,
    output [7:0] o_Rx_Byte,
    output o_Rx_DV,
    
    input i_Transmit,
    output o_Tx,
    input [7:0] i_Tx_Byte,
    output o_Tx_Active,
    output o_Tx_Done,
    
    output [7:0] o_debug

    );

//
// for now use the pb_down to trigger the tx
//
wire [15:0] clocks_per_bit = CLKS_PER_BIT;
wire [7:0] tdebug;
uart_tx TX (
    .i_Clocks_per_Bit(clocks_per_bit),
    .i_Clock(i_Clock),
    .i_Reset(i_Reset),
    .i_Tx_DV(i_Transmit),
    .i_Tx_Byte(i_Tx_Byte),
    .o_Tx_Serial(o_Tx),
    .o_Tx_Active(o_Tx_Active),
    .o_Tx_Done(o_Tx_Done),
    .o_debug(tdebug)
    );

wire [7:0] rdebug;
uart_rx RX  (
    .i_Clocks_per_Bit(clocks_per_bit),
    .i_Clock(i_Clock),
    .i_Reset(i_Reset),
    .i_Rx_Serial(i_Rx),
    .o_Rx_Byte(o_Rx_Byte),
    .o_Rx_DV(o_Rx_DV),
    .o_debug(rdebug)
    );

assign o_debug = {tdebug,rdebug};

endmodule
