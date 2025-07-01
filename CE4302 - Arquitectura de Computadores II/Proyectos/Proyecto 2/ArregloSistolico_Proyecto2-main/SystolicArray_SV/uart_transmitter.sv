// =============================================
// UART Transmisor
// =============================================
module uart_transmitter #(
    parameter CLOCK_FREQ = 50_000_000,  // 50 MHz
    parameter BAUD_RATE = 9600          // 9600 baudios para HC-05
)(
    input logic clk,
    input logic reset,
    input logic [7:0] data_in,          // Byte a transmitir
    input logic send,                   // Pulso para iniciar transmisión
    output logic tx,                    // Línea serie de transmisión
    output logic busy,                  // Ocupado transmitiendo
    output logic done                   // Transmisión completada
);

    // Cálculo de divisor de baudios
    localparam BAUD_DIVISOR = CLOCK_FREQ / BAUD_RATE;
    localparam COUNTER_WIDTH = $clog2(BAUD_DIVISOR);

    // Estados del transmisor
    typedef enum logic [2:0] {
        IDLE    = 3'd0,
        START   = 3'd1,
        DATA    = 3'd2,
        STOP    = 3'd3,
        CLEANUP = 3'd4
    } tx_state_t;

    // Registros internos
    tx_state_t state;
    logic [COUNTER_WIDTH-1:0] baud_counter;
    logic [7:0] shift_reg;
    logic [2:0] bit_counter;
    logic done_pulse;

    // Control de baudios
    logic baud_tick;
    assign baud_tick = (baud_counter == BAUD_DIVISOR - 1);

    always_ff @(posedge clk) begin
        if (reset) begin
            baud_counter <= 0;
        end else begin
            if (baud_tick || state == IDLE) begin
                baud_counter <= 0;
            end else begin
                baud_counter <= baud_counter + 1;
            end
        end
    end

    // Máquina de estados del transmisor
    always_ff @(posedge clk) begin
        if (reset) begin
            state <= IDLE;
            tx <= 1'b1;            // Línea inactiva alta
            shift_reg <= 8'h00;
            bit_counter <= 3'd0;
            done_pulse <= 1'b0;
        end else begin
            done_pulse <= 1'b0;    // Pulso de un ciclo
            
            case (state)
                IDLE: begin
                    tx <= 1'b1;
                    if (send) begin
                        shift_reg <= data_in;
                        bit_counter <= 3'd0;
                        state <= START;
                    end
                end
                
                START: begin
                    tx <= 1'b0;       // Bit de start
                    if (baud_tick) begin
                        state <= DATA;
                    end
                end
                
                DATA: begin
                    tx <= shift_reg[bit_counter];
                    if (baud_tick) begin
                        if (bit_counter == 3'd7) begin
                            state <= STOP;
                        end else begin
                            bit_counter <= bit_counter + 1;
                        end
                    end
                end
                
                STOP: begin
                    tx <= 1'b1;       // Bit de stop
                    if (baud_tick) begin
                        state <= CLEANUP;
                        done_pulse <= 1'b1;
                    end
                end
                
                CLEANUP: begin
                    tx <= 1'b1;
                    state <= IDLE;
                end
            endcase
        end
    end

    // Señales de salida
    assign busy = (state != IDLE);
    assign done = done_pulse;

endmodule