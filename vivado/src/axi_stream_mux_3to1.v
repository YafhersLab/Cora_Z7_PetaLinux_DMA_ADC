`timescale 1ns / 1ps
module axi_stream_mux_3to1 (
    input  wire        clk,
    input  wire        aresetn,
    // Selection signal from AXI GPIO (00=CH0, 01=CH1, 10=CH2, 11=CH3)
    input  wire [1:0]  sel,
    // Input channel 0
    input  wire [31:0] s0_axis_tdata,
    input  wire        s0_axis_tvalid,
    input  wire        s0_axis_tlast,
    output wire        s0_axis_tready,
    // Input channel 1
    input  wire [31:0] s1_axis_tdata,
    input  wire        s1_axis_tvalid,
    input  wire        s1_axis_tlast,
    output wire        s1_axis_tready,
    // Input channel 2
    input  wire [31:0] s2_axis_tdata,
    input  wire        s2_axis_tvalid,
    input  wire        s2_axis_tlast,
    output wire        s2_axis_tready,
    // Input channel 3
    input  wire [31:0] s3_axis_tdata,
    input  wire        s3_axis_tvalid,
    input  wire        s3_axis_tlast,
    output wire        s3_axis_tready,
    // Output towards AXI DMA
    output reg  [31:0] m_axis_tdata,
    output reg  [3:0]  m_axis_tkeep,
    output reg         m_axis_tvalid,
    output reg         m_axis_tlast,
    input  wire        m_axis_tready
);
    // Two-flop synchronizer for sel (prevents metastability from AXI GPIO clock domain)
    reg [1:0] sel_sync1, sel_sync2;
    always @(posedge clk or negedge aresetn) begin
        if (!aresetn) begin
            sel_sync1 <= 2'd0;
            sel_sync2 <= 2'd0;
        end else begin
            sel_sync1 <= sel;
            sel_sync2 <= sel_sync1;
        end
    end

    // Active channel - follows synchronized sel immediately, no TLAST required
    reg [1:0] active_sel;
    always @(posedge clk or negedge aresetn) begin
        if (!aresetn)
            active_sel <= 2'd0;
        else
            active_sel <= sel_sync2;
    end

    // Output mux - combinational based on active_sel
    always @(*) begin
        case (active_sel)
            2'd0: begin
                m_axis_tdata  = s0_axis_tdata;
                m_axis_tvalid = s0_axis_tvalid;
                m_axis_tlast  = s0_axis_tlast;
                m_axis_tkeep  = 4'b1111;
            end
            2'd1: begin
                m_axis_tdata  = s1_axis_tdata;
                m_axis_tvalid = s1_axis_tvalid;
                m_axis_tlast  = s1_axis_tlast;
                m_axis_tkeep  = 4'b1111;
            end
            2'd2: begin
                m_axis_tdata  = s2_axis_tdata;
                m_axis_tvalid = s2_axis_tvalid;
                m_axis_tlast  = s2_axis_tlast;
                m_axis_tkeep  = 4'b1111;
            end
            2'd3: begin
                m_axis_tdata  = s3_axis_tdata;
                m_axis_tvalid = s3_axis_tvalid;
                m_axis_tlast  = s3_axis_tlast;
                m_axis_tkeep  = 4'b1111;
            end
            default: begin
                m_axis_tdata  = 32'd0;
                m_axis_tvalid = 1'b0;
                m_axis_tlast  = 1'b0;
                m_axis_tkeep  = 4'b0000;
            end
        endcase
    end

    // TREADY only goes to active channel - others are blocked
    assign s0_axis_tready = (active_sel == 2'd0) ? m_axis_tready : 1'b0;
    assign s1_axis_tready = (active_sel == 2'd1) ? m_axis_tready : 1'b0;
    assign s2_axis_tready = (active_sel == 2'd2) ? m_axis_tready : 1'b0;
    assign s3_axis_tready = (active_sel == 2'd3) ? m_axis_tready : 1'b0;

endmodule