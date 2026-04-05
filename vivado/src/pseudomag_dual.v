module pseudomag_dual #(
    parameter IN_WIDTH = 16,   // Bits por parte real/imag
    parameter OUT_WIDTH = 16   // Bits de magnitud de salida
)(
    input  wire         aclk,
    input  wire         aresetn,

    // AXI4-Stream slave (entrada desde FFT)
    input  wire [31:0]  s_axis_tdata,
    input  wire         s_axis_tvalid,
    output wire         s_axis_tready,
    input  wire         s_axis_tlast,

    // Exponentes de bloque para ambos canales (cada uno 8 bits)
    input  wire [7:0]  block_exp_in,

    // AXI4-Stream master (salida hacia DMA)
    output reg  [15:0]  m_axis_tdata,
    output reg          m_axis_tvalid,
    input  wire         m_axis_tready,
    output reg          m_axis_tlast
);

    // Handshake AXI4-Stream
    assign s_axis_tready = m_axis_tready;

    // Separar canales y partes real/imag
    wire signed [IN_WIDTH-1:0] re_ch0 = s_axis_tdata[31:16];
    wire signed [IN_WIDTH-1:0] im_ch0 = s_axis_tdata[15:0];


    // Magnitud aproximada: max(|Re|,|Im|) + 0.5*min(|Re|,|Im|)
    wire [IN_WIDTH-1:0] abs_re_ch0 = re_ch0[IN_WIDTH-1] ? (~re_ch0 + 1'b1) : re_ch0;
    wire [IN_WIDTH-1:0] abs_im_ch0 = im_ch0[IN_WIDTH-1] ? (~im_ch0 + 1'b1) : im_ch0;
   

    wire [IN_WIDTH-1:0] max0 = (abs_re_ch0 > abs_im_ch0) ? abs_re_ch0 : abs_im_ch0;
    wire [IN_WIDTH-1:0] min0 = (abs_re_ch0 > abs_im_ch0) ? abs_im_ch0 : abs_re_ch0;


    // Suma y desplazamiento (>>1 equivale a dividir por 2)
    wire [IN_WIDTH:0] mag_ch0 = max0 + (min0 >> 1);

    // Saturación a OUT_WIDTH bits
    wire [OUT_WIDTH-1:0] mag_ch0_sat = (mag_ch0 > {OUT_WIDTH{1'b1}}) ? {OUT_WIDTH{1'b1}} : mag_ch0[OUT_WIDTH-1:0];
   
    // Exponentes individuales
    wire [7:0] exp_ch0 = block_exp_in[7:0];


    // Corrección por exponente (shift right)
    wire [OUT_WIDTH-1:0] mag_ch0_corr = mag_ch0_sat; //>> exp_ch0;


    // Registro de salida
    always @(posedge aclk) begin
        if (!aresetn) begin
            m_axis_tdata  <= 0;
            m_axis_tvalid <= 0;
            m_axis_tlast  <= 0;
        end else begin
            if (s_axis_tvalid && s_axis_tready) begin
                m_axis_tdata  <=  mag_ch0_corr;
                m_axis_tvalid <= 1'b1;
                m_axis_tlast  <= s_axis_tlast;
            end else if (m_axis_tvalid && !m_axis_tready) begin
                m_axis_tvalid <= m_axis_tvalid;
                m_axis_tlast  <= m_axis_tlast;
            end else begin
                m_axis_tvalid <= 1'b0;
                m_axis_tlast  <= 1'b0;
            end
        end
    end

endmodule