// =============================================
// UART Receptor
// =============================================
module uart_receiver #(
    parameter CLOCK_FREQ = 50_000_000,
    parameter BAUD_RATE = 9600
)(
    input logic clk,
    input logic reset,
    input logic rx,                     // Línea serie de recepción
    output logic [7:0] data_out,        // Byte recibido
    output logic data_valid,            // Dato válido recibido
    output logic error                  // Error de framing
);

    localparam BAUD_DIVISOR = CLOCK_FREQ / BAUD_RATE;
    localparam HALF_BAUD_DIVISOR = BAUD_DIVISOR / 2;
    localparam COUNTER_WIDTH = $clog2(BAUD_DIVISOR);

    typedef enum logic [2:0] {
        IDLE       = 3'd0,
        START_BIT  = 3'd1,
        DATA_BITS  = 3'd2,
        STOP_BIT   = 3'd3,
        CLEANUP    = 3'd4
    } rx_state_t;

    // Registros internos
    rx_state_t state;
    logic [COUNTER_WIDTH-1:0] baud_counter;
    logic [7:0] shift_reg;
    logic [2:0] bit_counter;
    logic rx_sync1, rx_sync2;          // Sincronizadores para rx

    // Control de baudios
    logic baud_tick, half_baud_tick;
    assign baud_tick = (baud_counter == BAUD_DIVISOR - 1);
    assign half_baud_tick = (baud_counter == HALF_BAUD_DIVISOR - 1);

    // Sincronización de entrada
    always_ff @(posedge clk) begin
        if (reset) begin
            rx_sync1 <= 1'b1;
            rx_sync2 <= 1'b1;
        end else begin
            rx_sync1 <= rx;
            rx_sync2 <= rx_sync1;
        end
    end

    // Contador de baudios
    always_ff @(posedge clk) begin
        if (reset) begin
            baud_counter <= 0;
        end else begin
            if (state == IDLE || baud_tick) begin
                baud_counter <= 0;
            end else begin
                baud_counter <= baud_counter + 1;
            end
        end
    end

    // Máquina de estados del receptor
    always_ff @(posedge clk) begin
        if (reset) begin
            state <= IDLE;
            data_out <= 8'h00;
            data_valid <= 1'b0;
            error <= 1'b0;
            shift_reg <= 8'h00;
            bit_counter <= 3'd0;
        end else begin
            data_valid <= 1'b0;   // Pulso de un ciclo
            error <= 1'b0;       // Pulso de un ciclo
            
            case (state)
                IDLE: begin
                    if (!rx_sync2) begin  // Detectar flanco de bajada (start bit)
                        state <= START_BIT;
                    end
                end
                
                START_BIT: begin
                    if (half_baud_tick) begin
                        if (!rx_sync2) begin  // Verificar start bit en el medio
                            state <= DATA_BITS;
                            bit_counter <= 3'd0;
                        end else begin
                            state <= IDLE;    // Falso start bit
                        end
                    end
                end
                
                DATA_BITS: begin
                    if (baud_tick) begin
                        shift_reg[bit_counter] <= rx_sync2;
                        if (bit_counter == 3'd7) begin
                            state <= STOP_BIT;
                        end else begin
                            bit_counter <= bit_counter + 1;
                        end
                    end
                end
                
                STOP_BIT: begin
                    if (baud_tick) begin
                        if (rx_sync2) begin   // Stop bit válido
                            data_out <= shift_reg;
                            data_valid <= 1'b1;
                        end else begin
                            error <= 1'b1;   // Error de framing
                        end
                        state <= CLEANUP;
                    end
                end
                
                CLEANUP: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule