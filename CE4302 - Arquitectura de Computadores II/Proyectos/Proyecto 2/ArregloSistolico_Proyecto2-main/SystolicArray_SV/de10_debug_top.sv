/**
 * Top level simplificado para debug inicial
 * Reemplaza temporalmente tu top level complejo
 */
module de10_debug_top (
    input logic clk_50mhz,          // PIN_AF14
    input logic reset_n,            // PIN_AJ4 (KEY[0])
    input logic hc05_rx,            // PIN_AH2
    output logic hc05_tx,           // PIN_AH3
    output logic [7:0] leds         // LEDR[7:0]
);

    simple_uart_debug debug_inst (
        .clk_50mhz(clk_50mhz),
        .reset_n(reset_n),
        .hc05_rx(hc05_rx),
        .hc05_tx(hc05_tx),
        .leds(leds),
        .debug_rx_valid(),
        .debug_tx_busy()
    );

endmodule