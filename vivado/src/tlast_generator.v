//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01.05.2025 19:52:55
// Design Name: 
// Module Name: tlast_generator
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

module tlast_generator (  
    input  wire        clk,  
    input  wire        aresetn,             // Señal de reinicio activo en bajo (asincrónico)  
    // Entrada desde el ADC  
    input  wire [31:0] s_axis_tdata,        // Entrada de datos TData  
    input  wire        s_axis_tvalid,       // Señal TValid del ADC  
    output wire        s_axis_tready,       // Señal TReady hacia el ADC  
    // Entrada desde Microblaze y GPIO  
    input  wire [15:0] buffer_size,       // Frecuencia desde GPIO  
    // Salida hacia el AXI DMA  
    output reg  [31:0] m_axis_tdata,        // Salida de datos TData  
    output reg         m_axis_tvalid,       // Señal TValid hacia el AXI DMA  
    output reg         m_axis_tlast,        // Señal TLast hacia el AXI DMA  
    output reg  [3:0]  m_axis_tkeep,        // Señal TKeep hacia el AXI DMA  
    input  wire        m_axis_tready        // Señal TReady desde el AXI DMA  
);  

    // Parámetro fijo para definir el multiplicador  
    localparam integer MULTIPLIER = 1;  

    // Registros internos  
    wire [20:0] max_count_reg;               // Valor máximo basado en `frecuencia_in`  
    reg [20:0] counter;                     // Contador de palabras procesadas  
    reg capturing;                          // Indica si está capturando activamente  

    // Señal TReady siempre activa mientras está capturando  
    assign s_axis_tready = capturing;  

    // Cálculo dinámico de `max_count` basado en `frecuencia_in`  
    assign max_count_reg = buffer_size * MULTIPLIER;
    
    // Lógica principal del generador  
    always @(posedge clk or negedge aresetn) begin  
        if (!aresetn) begin  
            // Reiniciar registros al reset  
            counter         <= 0;  
            capturing       <= 0;  
            m_axis_tdata    <= 0;  
            m_axis_tvalid   <= 0;  
            m_axis_tlast    <= 0;  
            m_axis_tkeep    <= 0;  

        end else begin  
            // Inicia captura cuando recibe `start_capture`  
            if (m_axis_tready && !capturing) begin  
                capturing <= 1;             // Activa captura  
                counter <= 0;               // Reinicia contador  
            end  

            if (capturing && s_axis_tvalid) begin  
                // Mientras se está capturando y los datos son válidos  
                m_axis_tdata <= s_axis_tdata;  // Copia datos del ADC al FIFO  
                m_axis_tvalid <= 1;           // Activa TValid hacia el AXI DMA  
                m_axis_tkeep <= 4'b1111;      // Mantiene TKeep activo  

                // Incrementa el contador si el DMA está listo  
                if (m_axis_tready) begin  
                    counter <= counter + 1;  

                    // Genera TLAST cuando alcanza el tamaño del buffer  
                    if (counter == (max_count_reg - 1)) begin  
                        m_axis_tlast <= 1;    // Señaliza última palabra del buffer  
                        capturing <= 0;       // Detiene captura  
                    end else begin  
                        m_axis_tlast <= 0;    // No genera TLAST aún  
                    end  
                end  
            end else begin  
                // Si no está capturando o el ADC no genera datos válidos  
                m_axis_tvalid <= 0;           // Desactiva TValid hacia el DMA  
                m_axis_tlast <= 0;            // Asegura que TLAST es cero  
                m_axis_tkeep <= 0;            // Apaga TKeep  
            end  
        end  
    end  
endmodule 
