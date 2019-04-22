`timescale 1ns / 1ps
//
// This project provides basic read / write commands for the cryoCMOS SRAM chiplet
//
// Top button resets
// Center button sets write value from switches
// Left button reads from current address
// Right button writes to current address
// Bottom button set address
// Right-most 8 switches are bits to write
// Right-most 9 switches are bits for setting address
// Right-most 8 LEDs are bits from last read
// Left-most display digit is version number
// Right-most three digits are currently set address
// Left-most switch should be left off (acts as reset for reset button)
//

// DEBOUNCE DELAY sets the minimum time the buttons can be pressed (in ticks)
module top (
    input clk,
    input btnT,
    input btnC,
    input btnL,
    input btnR,
    input btnD,
    //input reset,
    output RsTx,
    input RsRx,
    input [15:0] sw,
    output [15:0] led,
    output [6:0] segment,
    output dp,
    output [3:0] digit,
    output [7:0] JA,
    output [7:0] JB,
    input [7:0] JC,
    output [7:0] JXADC
    // synthesis translate_off
    , output [27:0] debug
    // synthesis translate_on
    );
    parameter DEBOUNCE_DELAY = 'd500;
    parameter CLK_DIVIDER = 'd100;
    parameter VERSION = 'd31;
    
    // Status of pins
    // 00 == ready
    // 01 == reading
    // 10 == swriting
    parameter [1:0] NONE = 2'b00;
    parameter [1:0] READ = 2'b01;
    parameter [1:0] WRITE = 2'b10;
    parameter [1:0] INVALID = 2'b11;
    wire [1:0] status;
    
    // Mode for state machine
    parameter [3:0] WAITING = 'hf;
    parameter [3:0] SETTING_ADDR = 'h1;
    parameter [3:0] WRITING_VAL = 'h2;
    parameter [3:0] READING_ADDR = 'h3;
    parameter [3:0] READING_VAL = 'h4;
    parameter [3:0] SETTING_CLK = 'h5;
    parameter [3:0] READING_CLK = 'h6;
    parameter [3:0] SETTING_READ_DELAY = 'h7;
    reg [3:0] mode = WAITING;
    
    // Stored data for read/write and driving clk
    reg [7:0] read_delay = 8'd4;
    reg [7:0] clk_factor = 8'd25;
    reg [8:0] address = 9'b0;
    reg [7:0] write = 8'b0;
    wire [7:0] read;
    reg reset = 1'b1; // reset line

    // Generate button signals
    //
    /*wire btop_pushed, btop_down, btop_up;
    wire [7:0] btop_debug;
    PB_Debouncer #(.DELAY(DEBOUNCE_DELAY)) top_debounce (
        .i_clk(clk),
        .i_reset(reset),
        .i_PB(btnT),
        .o_PB_state(btop_pushed),
        .o_PB_down(btop_down),
        .o_PB_up(btop_up),
        .o_debug(btop_debug)
        );*/
    wire bleft_pushed, bleft_down, bleft_up;
    wire [7:0] bleft_debug;
    PB_Debouncer #(.DELAY(DEBOUNCE_DELAY)) left_debounce (
        .i_clk(clk),
        .i_reset(reset),
        .i_PB(btnL),
        .o_PB_state(bleft_pushed),
        .o_PB_down(bleft_down),
        .o_PB_up(bleft_up),
        .o_debug(bleft_debug)
    );
    wire bcenter_pushed, bcenter_down, bcenter_up;
    wire [7:0] bcenter_debug;
    PB_Debouncer #(.DELAY(DEBOUNCE_DELAY)) center_debounce (
        .i_clk(clk),
        .i_reset(reset),
        .i_PB(btnC),
        .o_PB_state(bcenter_pushed),
        .o_PB_down(bcenter_down),
        .o_PB_up(bcenter_up),
        .o_debug(bcenter_debug)
    );
    wire bright_pushed, bright_down, bright_up;
    wire [7:0] bright_debug;
    PB_Debouncer #(.DELAY(DEBOUNCE_DELAY)) right_debounce (
        .i_clk(clk),
        .i_reset(reset),
        .i_PB(btnR),
        .o_PB_state(bright_pushed),
        .o_PB_down(bright_down),
        .o_PB_up(bright_up),
        .o_debug(bright_debug)
    );
    wire bbot_pushed, bbot_down, bbot_up;
    wire [7:0] bbot_debug;
    PB_Debouncer #(.DELAY(DEBOUNCE_DELAY)) bot_debounce (
        .i_clk(clk),
        .i_reset(reset),
        .i_PB(btnD),
        .o_PB_state(bbot_pushed),
        .o_PB_down(bbot_down),
        .o_PB_up(bbot_up),
        .o_debug(bbot_debug)
    );
    // Generate serial IO
    //
    //parameter CLOCK_DIVIDER = 100MHz/1Mbaud
    parameter WRITE_READY = 'hf;
    parameter WRITE_FIRST_TRIG = 'h1;
    parameter WRITE_FIRST_BYTE = 'h2;
    parameter WRITE_SECOND_TRIG = 'h3;
    parameter WRITE_SECOND_BYTE = 'h4;
    parameter READ_READY = 'hf;
    parameter READ_FIRST_TRIG = 'h1;
    parameter READ_FIRST_BYTE = 'h2;
    parameter READ_SECOND_TRIG = 'h3;
    parameter READ_SECOND_BYTE = 'h4;
    reg [3:0] read_seq = READ_READY;
    reg [3:0] write_seq = WRITE_READY;
    wire rx_dv;
    reg tx_dv = 0;
    wire [7:0] rx_data;
    wire [15:0] debugit;
    wire tx_ready;
    reg [7:0] tx_data = 0;
    wire tx_done;
    SerialIO  #(.CLKS_PER_BIT(CLK_DIVIDER)) serial (
        .i_Clock(clk),
        .i_Reset(reset),
        // transmitter:
        .o_Tx(RsTx),
        .i_Transmit(tx_dv),
        .i_Tx_Byte(tx_data),
        .o_Tx_Active(tx_ready),
        .o_Tx_Done(tx_done),
        // receiver:
        .i_Rx(RsRx),
        .o_Rx_Byte(rx_data),
        .o_Rx_DV(rx_dv),
    
        .o_debug(debugit)
        );
    
    // Actions!
    //
    reg serial_write = 0;
    reg serial_read = 0;
    wire write_trig = (bright_down | serial_write) & status == NONE;
    wire read_trig = (bleft_down | serial_read) & status == NONE;
    
    wire clk_sram_read;
    wire clk_sram_write;
   // clk_sram is high unless READ or WRITE - then track clk_sram_[read, write]
    wire clk_sram = ((1'b1 & status == NONE) | (clk_sram_read & status == READ) | (clk_sram_write & status == WRITE));
    // Work around so that two signals are not driving one output
    wire cen_sram_read;
    wire cen_sram_write;
   // cen_sram is high unless READ or WRITE - then track cen_sram_[read, write]
    wire cen_sram = ((1'b1 & status == NONE) | (cen_sram_read & status == READ) | (cen_sram_write & status == WRITE));
    wire wen_sram_read;
    wire wen_sram_write;
   // wen_sram is high unless READ or WRITE - then track wen_sram_[read, write]
    wire wen_sram = ((1'b1 & status == NONE) | (wen_sram_read & status == READ) | (wen_sram_write & status == WRITE));
    wire [8:0] a_sram_read;
    wire [8:0] a_sram_write;
   // a_sram is high unless READ or WRITE - then track a_sram_[read, write]
    wire [8:0] a_sram = ((9'hfff & {9{status == NONE}}) | (a_sram_read & {9{status == READ}}) | (a_sram_write & {9{status == WRITE}}));
    wire [7:0] d_sram;
    wire [7:0] q_sram;
    // read from sram
    ReadCycle read_cycle (
        .clk_factor(clk_factor),
        .read_delay(read_delay),
        .clk_in(clk),
        .reset_in(reset),
        .start_in(read_trig),
        .a_in(address),
        .q_in(q_sram),
        .clk_out(clk_sram_read),
        .cen_out(cen_sram_read),
        .wen_out(wen_sram_read),
        .a_out(a_sram_read),
        .q_out(read),
        .reading(status[0])
        );
    // write to sram
    WriteCycle write_cycle (
        .clk_factor(clk_factor),
        .clk_in(clk),
        .reset_in(reset),
        .start_in(write_trig),
        .a_in(address),
        .d_in(write),
        .clk_out(clk_sram_write),
        .cen_out(cen_sram_write),
        .wen_out(wen_sram_write),
        .a_out(a_sram_write),
        .d_out(d_sram),
        .writing(status[1])
        );
    
    // main control loop
    // bits for decoding >8-bit messages
    reg [3:0] rx_overflow = 0;
    always @(posedge clk) begin
        reset <= btnT;
        if (reset) begin
            // reset
            read_delay <= 8'd4;
            clk_factor <= 8'd25;
            address <= 9'b0;
            write <= 8'b0;
            mode <= WAITING;
            serial_write = 0;
            serial_read = 0;
            read_seq = READ_READY;
            write_seq = WRITE_READY;
            tx_dv = 0;
            tx_data = 0;
            rx_overflow = 0;
        end
        else
        // manual override
        if (bcenter_down) begin
            // store address
            address <= sw[8:0];
        end
        else
        if (bbot_down) begin
            // store write value
            write <= sw[7:0];
        end
        else
        if (sw[14]) begin
            // store clk factor
            clk_factor <= sw[7:0];
        end
        else
        if (sw[12]) begin
            // store delay
            read_delay <= sw[7:0];
        end
        else
        // serial com modes
        case (mode)
            WAITING : begin
                // monitor Rx byte
                read_seq <= READ_READY;
                write_seq <= WRITE_READY;
                if (rx_dv) begin
                    // if new read value -> update mode accordingly
                    mode <= rx_data[7:4];
                    // catch other bits in case we need them
                    rx_overflow <= rx_data[3:0];
                    read_seq <= READ_SECOND_TRIG;  
                end
            end
            
            SETTING_ADDR : begin
                // wait for second byte
                // set address to second byte
                // return to waiting
                case (read_seq)
                    READ_SECOND_TRIG : begin
                        if (~rx_dv) begin
                            // wait for first byte to finish
                            read_seq <= READ_SECOND_BYTE;
                        end
                    end
                    READ_SECOND_BYTE : begin
                        if (rx_dv) begin
                            // wait for second byte to end
                            // latch address
                            address <= {rx_overflow[0], rx_data[7:0]};
                            mode <= WAITING;
                            read_seq <= READ_READY;
                        end
                    end
                    default : begin
                        mode <= WAITING;
                    end
                endcase
            end
            
            WRITING_VAL : begin
                // wait for second byte
                // set write to second byte
                // perform write cycle
                // return to waiting
                case (read_seq)
                    READ_SECOND_TRIG : begin
                        if (~rx_dv) begin
                            // wait for first byte to finish
                            read_seq <= READ_SECOND_BYTE;
                        end
                    end
                    READ_SECOND_BYTE : begin
                        if (rx_dv) begin
                            // wait for second byte
                            // latch write value
                            write <= {rx_data[7:0]};
                            // trigger write cycle
                            serial_write <= 1;
                            read_seq <= READ_READY;
                        end
                    end
                    READ_READY : begin
                        if (serial_write) begin
                            // finish triggering write cycle
                            serial_write <= 0;
                        end
                        else
                        if (status != WRITE) begin
                            // after writing return to waiting
                            mode <= WAITING;
                        end
                    end
                    default : begin
                        mode <= WAITING;
                    end
                endcase
            end
            
            READING_ADDR : begin
                // transmit two bytes {read_addr[3:0], 000, a[8:0]}
                // return to waiting
                case (write_seq) 
                    WRITE_READY : begin
                        // first byte - initiate transmit sequence
                        tx_data <= {mode, 3'b0, address[8]};
                        write_seq <= WRITE_FIRST_TRIG;
                    end
                    WRITE_FIRST_TRIG : begin
                        if (~tx_dv) begin
                            // start trigger
                            tx_dv <= 1;
                        end
                        else begin
                            // end trigger
                            tx_dv <= 0;
                            write_seq <= WRITE_FIRST_BYTE;
                        end
                    end
                    WRITE_FIRST_BYTE : begin
                        if (tx_done) begin
                            // wait for uart to be ready for second byte
                            tx_data <= {address[7:0]};
                            write_seq <= WRITE_SECOND_TRIG;
                        end
                    end
                    WRITE_SECOND_TRIG : begin
                        if (~tx_dv) begin
                            // start trigger
                            tx_dv = 1;
                        end
                        else begin
                            // end trigger
                            tx_dv <= 0;
                            write_seq <= WRITE_SECOND_BYTE;
                        end
                    end
                    WRITE_SECOND_BYTE : begin
                        if (tx_done) begin
                            // second byte transmitted - reset
                            write_seq <= WRITE_READY;
                            mode <= WAITING;
                        end
                    end
                    default : begin
                        mode <= WAITING;
                    end
                endcase
            end
            
            READING_VAL : begin
                // perform read cycle
                // transmit two bytes {read_val[3:0], 0000, read[7:0]}
                // return to waiting
                case (write_seq)
                    WRITE_READY : begin
                        // first byte - initiate transmit sequence and read cycle
                        tx_data <= {mode, 4'b0};
                        write_seq <= WRITE_FIRST_TRIG;
                    end
                    WRITE_FIRST_TRIG : begin
                        if (~tx_dv | ~serial_read) begin
                            tx_dv <= 1;
                            serial_read <= 1;
                        end
                        else begin
                            // end trigger
                            tx_dv <= 0;
                            serial_read <= 0;
                            write_seq <= WRITE_FIRST_BYTE;
                        end
                    end
                    WRITE_FIRST_BYTE : begin
                        if (status != READ & tx_done) begin
                            // wait for read to finish and write to finish
                            tx_data <= {read};
                            write_seq <= WRITE_SECOND_TRIG;
                        end
                    end
                    WRITE_SECOND_TRIG : begin
                        if (~tx_dv) begin
                            // trigger write
                            tx_dv <= 1;
                        end
                        else begin
                            // end trigger
                            tx_dv <= 0;
                            write_seq <= WRITE_SECOND_BYTE;
                        end
                    end
                    WRITE_SECOND_BYTE : begin
                        if (tx_done) begin
                            // second byte transmitted - reset
                            write_seq <= WRITE_READY;
                            mode <= WAITING;
                        end
                    end
                    default : begin
                        mode <= WAITING;
                    end
                endcase
            end
            
            SETTING_CLK : begin
                // wait for second byte
                // set clk_factor to second byte
                // return to waiting
                case (read_seq)
                    READ_SECOND_TRIG : begin
                        if (~rx_dv) begin
                            // wait for first byte to finish
                            read_seq <= READ_SECOND_BYTE;
                        end
                    end
                    READ_SECOND_BYTE : begin
                        if (rx_dv) begin
                            // wait for second byte to finish
                            // latch clk_factor
                            clk_factor <= {rx_data[7:0]};
                            mode <= WAITING;
                            read_seq <= READ_READY;
                        end
                    end
                    default : begin
                        mode <= WAITING;
                    end
                endcase
            end
            
            READING_CLK : begin
                // transmit two bytes {read_clk[3:0], 0000, clk_factor[7:0]}
                // return to waiting
                case (write_seq)
                    WRITE_READY : begin
                        // first byte - initiate transmit sequence
                        tx_data <= {mode, 4'b0};
                        write_seq <= WRITE_FIRST_TRIG;
                    end
                    WRITE_FIRST_TRIG : begin
                        if (~tx_dv) begin
                            tx_dv <= 1;
                        end
                        else begin
                            // end trigger
                            tx_dv <= 0;
                            write_seq <= WRITE_FIRST_BYTE;
                        end
                    end
                    WRITE_FIRST_BYTE : begin
                        if (tx_done) begin
                            // wait for uart to be ready for second byte
                            tx_data <= {clk_factor[7:0]};
                            write_seq <= WRITE_SECOND_TRIG;
                        end
                    end
                    WRITE_SECOND_TRIG : begin
                        if (~tx_dv) begin
                            tx_dv <= 1;
                        end
                        else begin
                            // end trigger
                            tx_dv <= 0;
                            write_seq <= WRITE_SECOND_BYTE;
                        end
                    end
                    WRITE_SECOND_BYTE : begin
                        if (tx_done) begin
                            // second byte transmitted - reset
                            write_seq <= WRITE_READY;
                            mode <= WAITING;
                        end
                    end
                    default : begin
                        mode <= WAITING;
                    end
                endcase
            end // case: READING_CLK
            
            SETTING_READ_DELAY : begin
                // wait for second byte
                // set read_delay to second byte
                // return to waiting
                case (read_seq)
                    READ_SECOND_TRIG : begin
                        if (~rx_dv) begin
                            // wait for first byte to finish
                            read_seq <= READ_SECOND_BYTE;
                        end
                    end
                    READ_SECOND_BYTE : begin
                        if (rx_dv) begin
                            // wait for second byte to finish
                            // latch read_delay
                            read_delay <= {rx_data[7:0]};
                            mode <= WAITING;
                            read_seq <= READ_READY;
                        end
                    end
                    default : begin
                        mode <= WAITING;
                    end
                endcase
            end

            default : begin
                mode <= WAITING;
                read_seq <= READ_READY;
                write_seq <= WRITE_READY;
            end
        endcase
    end
    
    // Generate displays
    //
    wire [11:0] display_address = {3'b0, address & {9{~sw[15]}} & {9{~sw[13]}}};
    wire [11:0] display_clk = {4'b0, clk_factor & {8{sw[15]}} & {8{~sw[13]}}};
    wire [11:0] display_read_delay = {4'b0, read_delay & {8{sw[13]}}};
    wire [15:0] display_this = {mode[3:0], display_address | display_clk | display_read_delay};
    display4 DISPLAY (
        .clk100(clk),
        .number(display_this),
        .digit(digit),
        .segments(segment),
        .period()
    );
    assign led[15:8] = write;
    assign led[7:0] = read;
    assign dp = 1'b1;
   
    // Assign input/output pins
    //
    // synthesis translate_off
    assign debug = {reset, status, address, write, read};
    // synthesis translate_on
    
    // Function lines
    /*
    OBUF FUNC_OUT (.I({1'b1, status, wen_sram, cen_sram, clk_sram, a_sram[8], clk}), .O(JA));
    // Read lines
    IBUF READ_IN (.I(JB), .O(d_sram));
    // Write lines
    OBUF WRITE_OUT (.I(q_sram), .O(JC));
    // Addr lines
    OBUF ADDR_OUT (.I(a_sram), .O(JXADC));
    */
    assign JA = {1'b0, status, wen_sram, cen_sram, clk_sram, a_sram[8], 1'b0};
    assign JXADC = d_sram;
    assign q_sram = JC;
    assign JB = a_sram;
    
endmodule

/*
// Clock generation
//
wire clk25, clk12, clk06, clk03, clk01;
ClkSynth clk_synth (.clk_in(clk), .clk_out_04(clk25), .clk_out_08(clk12),
    .clk_out_16(clk06), .clk_out_32(clk03), .clk_out_64(clk01));
wire clk25c, clk12c, clk06c, clk03c, clk01c;
BUFG clk40_buf (.I(clk25),.O(clk25c));
BUFG clk20_buf (.I(clk12),.O(clk12c));
BUFG clk10_buf (.I(clk06),.O(clk06c));
BUFG clk5_buf (.I(clk03),.O(clk03c));
BUFG clk2p5_buf (.I(clk01),.O(clk01c));
*/



