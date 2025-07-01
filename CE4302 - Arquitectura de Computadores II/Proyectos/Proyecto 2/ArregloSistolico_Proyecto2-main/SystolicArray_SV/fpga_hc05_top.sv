// =============================================
// Top Level - Integración Completa
// =============================================
module fpga_hc05_top (
    // Clock y Reset
    input logic clk_50mhz,
    input logic reset_n,
    
    // Interfaz HC-05
    input logic hc05_rx,      // Pin conectado a TX del HC-05
    output logic hc05_tx,     // Pin conectado a RX del HC-05
    
    // LEDs de estado en la FPGA
    output logic [7:0] leds,
    
    // Señales de debug (opcional - para osciloscopio)
    output logic debug_processing,
    output logic debug_uart_active
);

    // Reset sincronizado
    logic reset;
    logic reset_sync1, reset_sync2;
    
    always_ff @(posedge clk_50mhz) begin
        reset_sync1 <= ~reset_n;
        reset_sync2 <= reset_sync1;
        reset <= reset_sync2;
    end

    // Señales de debug
    logic [7:0] last_cmd, last_rsp;
    logic comm_active;
    
    // Instancia del controlador principal
    uart_image_controller #(
        .CLOCK_FREQ(50_000_000),
        .BAUD_RATE(9600)
    ) main_controller (
        .clk(clk_50mhz),
        .reset(reset),
        .uart_rx(hc05_rx),
        .uart_tx(hc05_tx),
        .status_leds(leds),
        .last_command(last_cmd),
        .last_response(last_rsp),
        .communication_active(comm_active)
    );
    
    // Señales de debug
    assign debug_processing = leds[1];    // Procesando
    assign debug_uart_active = comm_active;

endmodule