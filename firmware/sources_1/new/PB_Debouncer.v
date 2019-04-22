`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////

module PB_Debouncer #(parameter DELAY='d5) (
    input i_clk,
    input i_reset,
    input i_PB,  // "PB" is the glitchy, asynchronous to clk, active low push-button signal

    output [7:0] o_debug,   // for debugging
    // from which we make three outputs, all synchronous to the clock
    output reg o_PB_state,  // 1 as long as the push-button is active (down)
    output reg o_PB_down,  // 1 for one clock cycle when the push-button goes down (i.e. just pushed)
    output reg o_PB_up   // 1 for one clock cycle when the push-button goes up (i.e. just released)
);

// First use two flip-flops to synchronize the PB signal the "clk" clock domain
reg PB0, PB1;  
always @(posedge i_clk) begin
    PB0 <= i_PB;  // invert PB to make PB_sync_0 active high
    PB1 <= PB0;
    end
wire trigger = PB0 & PB1;
//
// Next declare a counter.  Make it a half ms period, that should be enough, which
// means around 16 bits given a 10ns input clock
//
reg [15:0] PB_cnt;
//
// When the push-button is pushed or released, we increment the counter
// The counter has to be maxed out before we decide that the push-button state has changed
//
reg [2:0] state;
parameter [2:0] WAIT=0, COUNT_DOWN=1, IS_DOWN=2, WAIT2=3, COUNT_UP=4, IS_UP=5;
wire PB_cnt_max = (PB_cnt == DELAY);	// true when all bits of PB_cnt are 1's

always @(posedge i_clk or posedge i_reset)
    if (i_reset) begin
        o_PB_state <= 0;
        PB_cnt <= 0;
        o_PB_down <= 0;
        o_PB_up <= 0;
        state <= WAIT;
        end
    else 
        case (state)
            WAIT: begin
                o_PB_down <= 0;
                o_PB_state <= 0;
                o_PB_up <= 0;
                PB_cnt <= 0;
                if (trigger) state <= COUNT_DOWN;
                else state <= WAIT;
                end
            COUNT_DOWN: begin
                PB_cnt <= PB_cnt + 1;
                if (PB_cnt_max) state <= IS_DOWN;
                else state <= COUNT_DOWN;
                end
            IS_DOWN: begin
                o_PB_down <= 1;
                o_PB_state <= 1;
                PB_cnt <= 0;
                state <= WAIT2;
                end
            WAIT2: begin
                o_PB_down = 0; // 1 clock tick wide
                if (PB0 || PB1) state <= WAIT2;
                else state <= COUNT_UP;
                end
            COUNT_UP: begin
                PB_cnt <= PB_cnt + 1;
                if (PB_cnt_max) state <= IS_UP;
                else state <= COUNT_UP;
                end
            IS_UP: begin
                o_PB_up <= 1;
                state <= WAIT;
                end
            default: begin
                state <= WAIT;
                end
        endcase

assign o_debug = {state,o_PB_state,o_PB_down,o_PB_up,i_PB,trigger};
endmodule