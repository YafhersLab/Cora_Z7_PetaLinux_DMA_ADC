`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11.04.2025 11:23:34
// Design Name: 
// Module Name: pmod_ad1_interface
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


module pmod_ad1_interface (  
    input wire clk,               // Reloj del sistema (162.495938 MHz)  
    input wire reset,             // Señal de reset global (activo en bajo)  
    input wire [7:0] divider,     // Divisor configurable para el reloj SCK  
    input wire tready,            // Señal de AXI DMA: Listo para recibir datos  
    input wire enable,            // Entrada desde GPIO para habilitar la captura  
    input wire data1,             // Entrada del canal 1 del PMOD AD1 (MISO 1)  
    input wire data2,             // Entrada del canal 2 del PMOD AD1 (MISO 2)  
    output reg tvalid,            // Señal para indicar datos válidos  
    output reg [31:0] m_axi_data, // Datos concatenados para AXI DMA  
    output reg sck,               // Reloj serial (SCK)  
    output reg cs                 // Señal de chip select (CS) hacia el PMOD AD1  
);  

    // Registros y señales internas  
    reg [7:0] clk_counter = 0;      // Contador para dividir el reloj  
    reg [7:0] bit_counter = 0;      // Contador de los bits transferidos (16 bits)  
    reg [15:0] temp_data1 = 0;      // Registro para Data1 (canal 1)  
    reg [15:0] temp_data2 = 0;      // Registro para Data2 (canal 2)  
    reg capture_active = 0;         // Indica si la captura está habilitada  
    reg sck_tvalid_reg = 0;         // Almacena tvalid generado en el dominio sck  
    reg [31:0] sck_m_axi_data_reg = 0; // Almacena datos generados en el dominio sck  
    reg prev_sck_tvalid_reg = 0; 
    // **Síncrono a `clk`:  
    reg clk_tvalid_reg = 0;         // Registro para tvalid sincronizado al `clk`  
    reg [31:0] clk_m_axi_data_reg = 0; // Registro para datos sincronizados al `clk`  

    // Divisor del reloj para el SCK  
    always @(posedge clk or negedge reset) begin  
        if (!reset) begin  
            clk_counter <= 0;  
            sck <= 0;  
        end else if (clk_counter >= divider) begin  
            clk_counter <= 0;  
            sck <= ~sck;              // Generar un nuevo ciclo de reloj SCK  
        end else begin  
            clk_counter <= clk_counter + 1;  
        end  
    end  

    // Control de la señal CS  
    always @(posedge sck or negedge reset) begin  
        if (!reset) begin  
            cs <= 1;                 // CS en estado inactivo  
            capture_active <= 0;     // Captura deshabilitada  
        end else if (tready && enable && !capture_active) begin  
            cs <= 0;                 // Activar CS (bajar) al inicio de una transferencia  
            capture_active <= 1;     // Activar captura  
        end else if (bit_counter == 15) begin  
            cs <= 1;                 // Desactivar CS (subir) al finalizar una transferencia  
            capture_active <= 0;     // Finalizar captura  
        end  
    end  

    // FSM para la captura de datos en el dominio de `sck`  
    always @(negedge sck or negedge reset) begin  
        if (!reset) begin  
            bit_counter <= 0;  
            temp_data1 <= 0;  
            temp_data2 <= 0;  
            sck_tvalid_reg <= 0;  
        end else if (tready && enable && capture_active) begin  
            if (bit_counter < 15) begin  
                temp_data1 <= {temp_data1[14:0], data1}; // Captura desplazando  
                temp_data2 <= {temp_data2[14:0], data2}; // Captura desplazando  
                bit_counter <= bit_counter + 1;  
                sck_tvalid_reg <= 0; // Inactivo mientras captura  
            end else begin  
                sck_m_axi_data_reg <= {temp_data1[15:0], temp_data2[15:0]}; // Concatenar datos  
                sck_tvalid_reg <= 1;      // Notificar datos válidos  
                bit_counter <= 0;         // Reiniciar contador  
                temp_data1 <= 0;          // Borrar registros temporales  
                temp_data2 <= 0;          // Borrar registros temporales  
            end  
        end else begin  
            sck_tvalid_reg <= 0;          // Forzar inactivo fuera de captura  
        end  
    end  

    // Sincronización con el dominio clk  
    always @(posedge clk or negedge reset) begin  
        if (!reset) begin  
            clk_tvalid_reg <= 0;  
            clk_m_axi_data_reg <= 0;  
            prev_sck_tvalid_reg <= 0;  
        end else begin  
            clk_tvalid_reg <= sck_tvalid_reg;      // Absorbe el valor 'bruto'  
            clk_m_axi_data_reg <= sck_m_axi_data_reg; // Datos sincronizados  
            prev_sck_tvalid_reg <= clk_tvalid_reg; // Guarda el valor anterior  
        end  
    end  
    
    // Generación del pulso de tvalid (sólo un ciclo de clk)  
    always @(posedge clk or negedge reset) begin  
        if (!reset) begin  
            tvalid <= 0;  
            m_axi_data <= 0;  
        end else begin  
            // Pulso cuando hay flanco ascendente de clk_tvalid_reg  
            tvalid <= (clk_tvalid_reg && !prev_sck_tvalid_reg);  
            m_axi_data <= clk_m_axi_data_reg; // (Puede quedarse o mantenerse, dependiendo tu lógica)  
        end
     end  
endmodule        