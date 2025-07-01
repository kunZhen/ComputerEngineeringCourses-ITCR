/**
 * Top Level específico para DE10 Standard Board
 * Basado en tu fpga_hc05_top existente, adaptado para DE10 Standard
 */

module de10_standard_top (
    // Clock principal (50MHz) - PIN_AF14
    input logic clk_50mhz,
    
    // Reset button (KEY[0] - activo bajo) - PIN_AJ4  
    input logic reset_n,
    
    // Interfaz HC-05 Bluetooth - GPIO Header J5
    input logic hc05_rx,      // PIN_AH2 (GPIO_0[0]) - Conectar a TX del HC-05
    output logic hc05_tx,     // PIN_AH3 (GPIO_0[1]) - Conectar a RX del HC-05
    
    // LEDs de estado (LEDR[7:0])
    output logic [7:0] leds   // PIN_AA24, PIN_AB23, PIN_AC23, PIN_AD24,
                              // PIN_AG25, PIN_AF25, PIN_AE24, PIN_AF24
);

    // =============================================
    // Reset Synchronizer para DE10 Standard
    // =============================================
    logic reset_sync;
    logic reset_ff1, reset_ff2;
    
    // Sincronizador de reset para KEY[0] (activo bajo)
    always_ff @(posedge clk_50mhz or negedge reset_n) begin
        if (!reset_n) begin
            reset_ff1 <= 1'b1;
            reset_ff2 <= 1'b1;
        end else begin
            reset_ff1 <= 1'b0;
            reset_ff2 <= reset_ff1;
        end
    end
    
    assign reset_sync = reset_ff2;

    // =============================================
    // Señales de debug internas
    // =============================================
    logic [7:0] last_cmd_debug;
    logic [7:0] last_rsp_debug;
    logic comm_active_debug;
    
    // =============================================
    // Instancia del Controlador Principal
    // (Reutilizando tu uart_image_controller existente)
    // =============================================
    uart_image_controller #(
        .CLOCK_FREQ(50_000_000),    // 50 MHz clock de la DE10 Standard
        .BAUD_RATE(9600)            // HC-05 standard baud rate
    ) main_controller (
        .clk(clk_50mhz),
        .reset(reset_sync),
        
        // UART HC-05 interface
        .uart_rx(hc05_rx),
        .uart_tx(hc05_tx),
        
        // Status LEDs (mapped to LEDR[7:0])
        .status_leds(leds),
        
        // Debug signals (internal monitoring)
        .last_command(last_cmd_debug),
        .last_response(last_rsp_debug),
        .communication_active(comm_active_debug)
    );

    // =============================================
    // Opcional: Debug signals para GPIO externos
    // (Descomentar si quieres monitorear con osciloscopio)
    // =============================================
    /*
    output logic debug_processing,     // GPIO_0[2] - PIN_Y16
    output logic debug_uart_active,    // GPIO_0[3] - PIN_AA19
    output logic [7:0] debug_cmd_out,  // GPIO_0[11:4] 
    
    assign debug_processing = leds[1];        // LED[1] = procesando
    assign debug_uart_active = comm_active_debug;
    assign debug_cmd_out = last_cmd_debug;
    */

endmodule