module axi_stream_mux_3to1 (
    input  wire        clk,
    input  wire        aresetn,

    // Señal de selección desde AXI GPIO (00=DDS0, 01=DDS1, 10=DDS2)
    input  wire [1:0]  sel,

    // Entrada DDS 0
    input  wire [31:0] s0_axis_tdata,
    input  wire        s0_axis_tvalid,
    input  wire        s0_axis_tlast,
    output wire        s0_axis_tready,

    // Entrada DDS 1
    input  wire [31:0] s1_axis_tdata,
    input  wire        s1_axis_tvalid,
    input  wire        s1_axis_tlast,
    output wire        s1_axis_tready,

    // Entrada DDS 2
    input  wire [31:0] s2_axis_tdata,
    input  wire        s2_axis_tvalid,
    input  wire        s2_axis_tlast,
    output wire        s2_axis_tready,

    // Salida hacia tlast_generator / FIFO
    output reg  [31:0] m_axis_tdata,
    output reg         m_axis_tvalid,
    output reg         m_axis_tlast,
    input  wire        m_axis_tready
);

    // Canal activo - solo cambia cuando termina un paquete
    reg [1:0] active_sel;

    // Actualiza la selección activa solo entre paquetes
    always @(posedge clk or negedge aresetn) begin
        if (!aresetn) begin
            active_sel <= 2'd0;
        end else begin
            // Cambia de canal cuando el paquete actual termina
            // (TLAST del canal activo se transfiere exitosamente)
            case (active_sel)
                2'd0: if (s0_axis_tvalid && s0_axis_tlast && m_axis_tready)
                          active_sel <= sel;
                2'd1: if (s1_axis_tvalid && s1_axis_tlast && m_axis_tready)
                          active_sel <= sel;
                2'd2: if (s2_axis_tvalid && s2_axis_tlast && m_axis_tready)
                          active_sel <= sel;
                default: active_sel <= 2'd0;
            endcase
        end
    end

    // Lógica de salida - mux combinacional basado en active_sel
    always @(*) begin
        case (active_sel)
            2'd0: begin
                m_axis_tdata  = s0_axis_tdata;
                m_axis_tvalid = s0_axis_tvalid;
                m_axis_tlast  = s0_axis_tlast;
            end
            2'd1: begin
                m_axis_tdata  = s1_axis_tdata;
                m_axis_tvalid = s1_axis_tvalid;
                m_axis_tlast  = s1_axis_tlast;
            end
            2'd2: begin
                m_axis_tdata  = s2_axis_tdata;
                m_axis_tvalid = s2_axis_tvalid;
                m_axis_tlast  = s2_axis_tlast;
            end
            default: begin
                m_axis_tdata  = 32'd0;
                m_axis_tvalid = 1'b0;
                m_axis_tlast  = 1'b0;
            end
        endcase
    end

    // TREADY solo va al canal activo - los demás se ignoran
    assign s0_axis_tready = (active_sel == 2'd0) ? m_axis_tready : 1'b0;
    assign s1_axis_tready = (active_sel == 2'd1) ? m_axis_tready : 1'b0;
    assign s2_axis_tready = (active_sel == 2'd2) ? m_axis_tready : 1'b0;

endmodule