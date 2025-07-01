/**
 * Módulo UART Simplificado para Debug
 * Usa este módulo temporalmente para verificar conectividad básica
 */

module simple_uart_debug (
    // Clock y Reset
    input logic clk_50mhz,          // PIN_AF14
    input logic reset_n,            // PIN_AJ4 (KEY[0])
    
    // UART HC-05
    input logic hc05_rx,            // PIN_AH2 
    output logic hc05_tx,           // PIN_AH3
    
    // LEDs debug
    output logic [7:0] leds,        // LEDR[7:0]
    
    // Debug outputs (opcional)
    output logic debug_rx_valid,
    output logic debug_tx_busy
);

    // =============================================
    // Reset sincronizado
    // =============================================
    logic reset;
    logic reset_ff1, reset_ff2;
    
    always_ff @(posedge clk_50mhz or negedge reset_n) begin
        if (!reset_n) begin
            reset_ff1 <= 1'b1;
            reset_ff2 <= 1'b1;
        end else begin
            reset_ff1 <= 1'b0;
            reset_ff2 <= reset_ff1;
        end
    end
    
    assign reset = reset_ff2;

    // =============================================
    // Señales UART
    // =============================================
    logic [7:0] rx_data, tx_data;
    logic rx_valid, rx_error;
    logic tx_send, tx_busy, tx_done;
    
    // =============================================
    // Instancias UART (reutilizar de código anterior)
    // =============================================
    uart_receiver #(
        .CLOCK_FREQ(50_000_000),
        .BAUD_RATE(9600)
    ) uart_rx (
        .clk(clk_50mhz),
        .reset(reset),
        .rx(hc05_rx),
        .data_out(rx_data),
        .data_valid(rx_valid),
        .error(rx_error)
    );
    
    uart_transmitter #(
        .CLOCK_FREQ(50_000_000),
        .BAUD_RATE(9600)
    ) uart_tx (
        .clk(clk_50mhz),
        .reset(reset),
        .data_in(tx_data),
        .send(tx_send),
        .tx(hc05_tx),
        .busy(tx_busy),
        .done(tx_done)
    );

    // =============================================
    // Lógica de Debug Simple
    // =============================================
    
    // Modo de operación
    typedef enum logic [2:0] {
        MODE_ECHO     = 3'd0,    // Echo simple
        MODE_FIXED    = 3'd1,    // Respuesta fija
        MODE_COUNTER  = 3'd2,    // Contador
        MODE_PATTERN  = 3'd3     // Patrón conocido
    } debug_mode_t;
    
    debug_mode_t current_mode;
    logic [7:0] counter;
    logic [31:0] heartbeat_counter;
    logic heartbeat_pulse;
    
    // Heartbeat cada segundo (50M ciclos)
    always_ff @(posedge clk_50mhz) begin
        if (reset) begin
            heartbeat_counter <= 0;
            heartbeat_pulse <= 0;
        end else begin
            if (heartbeat_counter >= 50_000_000 - 1) begin
                heartbeat_counter <= 0;
                heartbeat_pulse <= 1;
            end else begin
                heartbeat_counter <= heartbeat_counter + 1;
                heartbeat_pulse <= 0;
            end
        end
    end
    
    // Máquina de estados simple
    typedef enum logic [2:0] {
        IDLE        = 3'd0,
        PROCESS_RX  = 3'd1,
        SEND_RESPONSE = 3'd2,
        WAIT_TX     = 3'd3,
        HEARTBEAT   = 3'd4
    } state_t;
    
    state_t state;
    logic [7:0] last_received;
    logic [7:0] response_byte;
    
    // Control principal
    always_ff @(posedge clk_50mhz) begin
        if (reset) begin
            state <= IDLE;
            tx_send <= 0;
            tx_data <= 8'h00;
            last_received <= 8'h00;
            response_byte <= 8'h00;
            counter <= 8'h00;
            current_mode <= MODE_ECHO;
        end else begin
            tx_send <= 0;  // Por defecto
            
            case (state)
                IDLE: begin
                    if (rx_valid && !rx_error) begin
                        last_received <= rx_data;
                        state <= PROCESS_RX;
                    end else if (heartbeat_pulse) begin
                        state <= HEARTBEAT;
                    end
                end
                
                PROCESS_RX: begin
                    // Decidir respuesta basado en comando recibido
                    case (last_received)
                        8'h50: begin // 'P' - Ping
                            response_byte <= 8'h4F; // 'O' - Pong
                        end
                        8'h45: begin // 'E' - Echo mode
                            current_mode <= MODE_ECHO;
                            response_byte <= 8'h41; // 'A' - ACK
                        end
                        8'h46: begin // 'F' - Fixed mode
                            current_mode <= MODE_FIXED;
                            response_byte <= 8'h41; // 'A' - ACK
                        end
                        8'h43: begin // 'C' - Counter mode
                            current_mode <= MODE_COUNTER;
                            response_byte <= 8'h41; // 'A' - ACK
                        end
                        default: begin
                            // Respuesta según modo actual
                            case (current_mode)
                                MODE_ECHO: response_byte <= last_received;
                                MODE_FIXED: response_byte <= 8'h42; // 'B'
                                MODE_COUNTER: begin
                                    response_byte <= counter;
                                    counter <= counter + 1;
                                end
                                MODE_PATTERN: response_byte <= 8'h55; // Patrón 0x55
                            endcase
                        end
                    endcase
                    state <= SEND_RESPONSE;
                end
                
                SEND_RESPONSE: begin
                    if (!tx_busy) begin
                        tx_data <= response_byte;
                        tx_send <= 1;
                        state <= WAIT_TX;
                    end
                end
                
                WAIT_TX: begin
                    if (tx_done) begin
                        state <= IDLE;
                    end
                end
                
                HEARTBEAT: begin
                    // Enviar heartbeat automático
                    if (!tx_busy) begin
                        tx_data <= 8'h48; // 'H' - Heartbeat
                        tx_send <= 1;
                        state <= WAIT_TX;
                    end
                end
            endcase
        end
    end
    
    // =============================================
    // LEDs de Estado
    // =============================================
    always_comb begin
        leds[0] = rx_valid;           // Dato recibido
        leds[1] = tx_busy;            // Transmitiendo
        leds[2] = rx_error;           // Error RX
        leds[3] = (state != IDLE);    // Procesando
        leds[4] = (current_mode == MODE_ECHO);     // Modo Echo
        leds[5] = (current_mode == MODE_FIXED);    // Modo Fixed
        leds[6] = (current_mode == MODE_COUNTER);  // Modo Counter
        leds[7] = heartbeat_pulse;    // Heartbeat
    end
    
    // Debug outputs
    assign debug_rx_valid = rx_valid;
    assign debug_tx_busy = tx_busy;

endmodule