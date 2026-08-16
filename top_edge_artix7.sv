`timescale 1ns / 1ps

module top_edge_artix7 (
    input  logic       clk,        // 50 MHz Pin N11
    input  logic       rst_btn,    // Active-High Pushbutton Pin K13
    input  logic       uart_rx_i,  // Onboard USB-UART RX Pin D4
    output logic [6:0] Seven_Seg,  // Cathodes: G2, G1, H5, H4, J5, J4, H2
    output logic [3:0] digit_en,   // Anodes: F2, E1, G5, G4
    output logic [3:0] led         // Status LEDs
);

    logic       rx_valid;
    logic [7:0] rx_byte;
    (* ram_style = "block" *) logic [7:0] img_ram [0:783];
    logic [9:0] pixel_idx = '0;
    logic       nn_start  = 1'b0;

    logic [7:0] l1_out [0:63];
    logic [7:0] l2_out [0:9];
    logic       l1_done;
    logic       l2_done;

    logic [3:0] predicted_digit = 4'h0;
    logic       receiving = 1'b0;

    // UART Receiver Instance
    uart_rx #(
        .CLK_FREQ(50000000),
        .BAUD_RATE(115200)
    ) u_uart (
        .clk(clk),
        .rst(rst_btn),
        .rx(uart_rx_i),
        .data_out(rx_byte),
        .valid(rx_valid)
    );

    // Pixel Stream Capture Logic with Frame Synchronization
    always_ff @(posedge clk or posedge rst_btn) begin
        if (rst_btn) begin
            pixel_idx <= '0;
            nn_start  <= 1'b0;
            receiving <= 1'b0;
        end else if (rx_valid) begin
            if (!receiving) begin
                // Check for Packet Header 0xAA (170)
                if (rx_byte == 8'hAA) begin 
                    receiving <= 1'b1;
                    pixel_idx <= '0;
                    nn_start  <= 1'b0;
                end
            end else begin
                // Store actual pixels
                img_ram[pixel_idx] <= rx_byte;
                if (pixel_idx == 10'd783) begin
                    pixel_idx <= '0;
                    nn_start  <= 1'b1; // Trigger inference
                    receiving <= 1'b0; // Wait for next frame header
                end else begin
                    pixel_idx <= pixel_idx + 1'b1;
                    nn_start  <= 1'b0;
                end
            end
        end else begin
            nn_start <= 1'b0;
        end
    end

    // Layer 1: Fully Connected Engine (784 -> 64 with ReLU)
    single_fc_engine #(
        .IN_NODES(784),
        .OUT_NODES(64),
        .IS_RELU(1),
        .MEM_WEIGHT("l1_weights.mem"),
        .MEM_BIAS("l1_biases.mem")
    ) layer1_inst (
        .clk(clk),
        .rst(rst_btn),
        .start(nn_start),
        .in_vec(img_ram),
        .out_vec(l1_out),
        .done(l1_done)
    );

    // Layer 2: Fully Connected Engine (64 -> 10 output classes)
    single_fc_engine #(
        .IN_NODES(64),
        .OUT_NODES(10),
        .IS_RELU(0),
        .MEM_WEIGHT("l2_weights.mem"),
        .MEM_BIAS("l2_biases.mem")
    ) layer2_inst (
        .clk(clk),
        .rst(rst_btn),
        .start(l1_done),
        .in_vec(l1_out),
        .out_vec(l2_out),
        .done(l2_done)
    );

    // Argmax Classification Logic
    integer i;
    logic signed [7:0] max_val;
    always_ff @(posedge clk or posedge rst_btn) begin
        if (rst_btn) begin
            predicted_digit <= 4'h0;
        end else if (l2_done) begin
            max_val = signed'(l2_out[0]);
            predicted_digit <= 4'd0;
            for (i = 1; i < 10; i = i + 1) begin
                if (signed'(l2_out[i]) > max_val) begin
                    max_val = signed'(l2_out[i]);
                    predicted_digit <= i[3:0];
                end
            end
        end
    end

    // 7-Segment Decoder
    logic [6:0] seg_out;
    always_comb begin
        unique case (predicted_digit)
            4'd0: seg_out = 7'b1000000;
            4'd1: seg_out = 7'b1111001;
            4'd2: seg_out = 7'b0100100;
            4'd3: seg_out = 7'b0110000;
            4'd4: seg_out = 7'b0011001;
            4'd5: seg_out = 7'b0010010;
            4'd6: seg_out = 7'b0000010;
            4'd7: seg_out = 7'b1111000;
            4'd8: seg_out = 7'b0000000;
            4'd9: seg_out = 7'b0010000;
            default: seg_out = 7'b1111111;
        endcase
    end

    assign Seven_Seg = seg_out;
    assign digit_en  = 4'b1000; // Active-high rightmost digit

    // Stretched LED indicator
    logic [23:0] rx_pulse = '0;
    always_ff @(posedge clk) begin
        if (rx_valid) rx_pulse <= 24'd12_500_000; 
        else if (rx_pulse > 0) rx_pulse <= rx_pulse - 1'b1;
    end

    assign led[0] = (rx_pulse > 0); 
    assign led[1] = nn_start;       
    assign led[2] = l2_done;        
    assign led[3] = receiving; // Lights up when actively receiving a framed packet

endmodule