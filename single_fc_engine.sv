`timescale 1ns / 1ps

module single_fc_engine #(
    parameter int IN_NODES   = 784,
    parameter int OUT_NODES  = 64,
    parameter bit IS_RELU    = 1,
    parameter string MEM_WEIGHT = "l1_weights.mem",
    parameter string MEM_BIAS   = "l1_biases.mem"
)(
    input  logic       clk,
    input  logic       rst,
    input  logic       start,
    input  logic [7:0] in_vec [0:IN_NODES-1],
    output logic [7:0] out_vec [0:OUT_NODES-1],
    output logic       done
);
    (* ram_style = "block" *) logic signed [7:0] weights [0:(IN_NODES * OUT_NODES) - 1];
    logic signed [7:0] biases [0:OUT_NODES - 1];

    initial begin
        $readmemh(MEM_WEIGHT, weights);
        $readmemh(MEM_BIAS, biases);
    end

    logic [15:0] in_ptr;
    logic [15:0] out_ptr;
    logic signed [31:0] accumulator;
    logic [1:0] state;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            done        <= 1'b0;
            state       <= '0;
            in_ptr      <= '0;
            out_ptr     <= '0;
            accumulator <= '0;
        end else begin
            unique case (state)
                2'd0: begin
                    done <= 1'b0;
                    if (start) begin
                        in_ptr      <= '0;
                        out_ptr     <= '0;
                        accumulator <= {{17{biases[0][7]}}, biases[0], 7'b0};
                        state       <= 2'd1;
                    end
                end
                2'd1: begin
                    // Signed casting applied here to prevent DC offset errors
                    accumulator <= accumulator + (signed'(in_vec[in_ptr]) * signed'(weights[out_ptr * IN_NODES + in_ptr]));
                    
                    if (in_ptr == IN_NODES - 1) begin
                        in_ptr <= '0;
                        
                        // Output Quantization & ReLU
                        if (IS_RELU && accumulator < 0) begin
                            out_vec[out_ptr] <= 8'd0;
                        end else begin
                            if ((accumulator >>> 7) > 32'sd127)
                                out_vec[out_ptr] <= 8'd127;
                            else if ((accumulator >>> 7) < -32'sd128)
                                out_vec[out_ptr] <= -8'sd128;
                            else
                                out_vec[out_ptr] <= accumulator[14:7];
                        end

                        if (out_ptr == OUT_NODES - 1) begin
                            state <= 2'd2;
                        end else begin
                            out_ptr     <= out_ptr + 1'b1;
                            accumulator <= {{17{biases[out_ptr + 1][7]}}, biases[out_ptr + 1], 7'b0};
                        end
                    end else begin
                        in_ptr <= in_ptr + 1'b1;
                    end
                end
                2'd2: begin
                    done  <= 1'b1;
                    state <= 2'd0;
                end
                default: state <= 2'd0;
            endcase
        end
    end
endmodule