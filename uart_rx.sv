`timescale 1ns / 1ps

module uart_rx #(
    parameter integer CLK_FREQ = 50000000,
    parameter integer BAUD_RATE = 115200
)(
    input  logic       clk,
    input  logic       rst,
    input  logic       rx,
    output logic [7:0] data_out,
    output logic       valid
);
    localparam integer CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;
    typedef enum logic [1:0] {
        IDLE  = 2'b00,
        START = 2'b01,
        DATA  = 2'b10,
        STOP  = 2'b11
    } state_t;

    state_t state = IDLE;
    logic [15:0] clk_cnt = '0;
    logic [2:0]  bit_idx = '0;
    logic [7:0]  rx_shifter = '0;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            state      <= IDLE;
            valid      <= 1'b0;
            clk_cnt    <= '0;
            bit_idx    <= '0;
            data_out   <= '0;
            rx_shifter <= '0;
        end else begin
            valid <= 1'b0;
            unique case (state)
                IDLE: begin
                    clk_cnt <= '0;
                    bit_idx <= '0;
                    if (~rx) state <= START;
                end
                START: begin
                    if (clk_cnt == (CLKS_PER_BIT - 1) / 2) begin
                        if (~rx) begin
                            clk_cnt <= '0;
                            state   <= DATA;
                        end else begin
                            state <= IDLE;
                        end
                    end else begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end
                end
                DATA: begin
                    if (clk_cnt < CLKS_PER_BIT - 1) begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end else begin
                        clk_cnt <= '0;
                        rx_shifter[bit_idx] <= rx;
                        if (bit_idx < 7) begin
                            bit_idx <= bit_idx + 1'b1;
                        end else begin
                            bit_idx <= '0;
                            state   <= STOP;
                        end
                    end
                end
                STOP: begin
                    if (clk_cnt < CLKS_PER_BIT - 1) begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end else begin
                        valid    <= 1'b1;
                        data_out <= rx_shifter;
                        clk_cnt  <= '0;
                        state    <= IDLE;
                    end
                end
                default: state <= IDLE;
            endcase
        end
    end
endmodule