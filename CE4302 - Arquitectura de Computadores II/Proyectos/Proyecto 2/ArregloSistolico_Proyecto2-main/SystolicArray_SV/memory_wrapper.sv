/**
 * Memory Wrapper con Manejo Correcto de Latencia para RAM IP
 * 
 * Características:
 * - Manejo de latencia de lectura de 1-2 ciclos
 * - Señales de handshaking (valid/ready)
 * - Pipeline para mantener throughput
 * - Compatible con image_processor existente
 */

module memory_wrapper #(
    parameter DATA_WIDTH = 32,
    parameter ADDRESS_WIDTH = 32,
    parameter MEM_SIZE = 8192,          // Must match IP RAM size (2^13 = 8192)
    parameter READ_LATENCY = 2          // RAM IP read latency in cycles
)(
    // Original memory interface (compatible with image_processor)
    input logic clk,
    input logic reset,
    input logic [ADDRESS_WIDTH-1:0] address,
    input logic [DATA_WIDTH-1:0] write_data,
    input logic we,                    // Write enable
    input logic re,                    // Read enable  
    input logic be,                    // Byte enable (1=byte, 0=word)
    output logic [DATA_WIDTH-1:0] read_data,
    
    // Handshaking signals
    output logic read_valid,           // Read data is valid
    output logic read_ready,           // Ready to accept new read request
    output logic write_ready,          // Ready to accept new write request
    
    // Performance counters
    output logic [DATA_WIDTH-1:0] read_count,
    output logic [DATA_WIDTH-1:0] write_count,
    output logic [DATA_WIDTH-1:0] bytes_transferred
);

    // =============================================
    // Internal Signals
    // =============================================
    
    // Address conversion and validation
    logic [12:0] ram_address;          // 13-bit address for IP RAM
    logic address_valid;               // Address within valid range
    
    // Byte enable conversion
    logic [3:0] ram_byteena;           // 4-bit byte enable for IP RAM
    
    // Data flow control
    logic ram_wren, ram_rden;          // Write/read enables for IP RAM
    logic [31:0] ram_data_in;          // Data input to IP RAM
    logic [31:0] ram_data_out;         // Data output from IP RAM
    
    // Latency handling pipeline
    logic [READ_LATENCY-1:0] read_pipe_valid;   // Pipeline valid bits
    logic [READ_LATENCY-1:0] read_pipe_be;      // Pipeline byte enable
    logic [ADDRESS_WIDTH-1:0] read_pipe_addr [READ_LATENCY-1:0]; // Pipeline addresses
    
    // Performance counters
    logic [31:0] read_counter;
    logic [31:0] write_counter;
    logic [31:0] bytes_counter;
    
    // Reset state tracking
    logic reset_done;
    logic [15:0] reset_counter;
    
    // Request tracking
    logic read_request_pending;
    logic write_request_pending;

    // =============================================
    // Address Conversion and Validation
    // =============================================
    
    always_comb begin
        // Convert 32-bit address to 13-bit word address
        ram_address = address[14:2];   // Word-aligned address (bits [14:2])
        
        // Validate address range
        address_valid = (address < (MEM_SIZE * 4)) && (address[1:0] == 2'b00 || be);
    end

    // =============================================
    // Byte Enable Conversion
    // =============================================
    
    always_comb begin
        if (be) begin
            // Byte access - enable specific byte based on address[1:0]
            case (address[1:0])
                2'b00: ram_byteena = 4'b0001;  // Enable byte 0
                2'b01: ram_byteena = 4'b0010;  // Enable byte 1
                2'b10: ram_byteena = 4'b0100;  // Enable byte 2
                2'b11: ram_byteena = 4'b1000;  // Enable byte 3
            endcase
        end else begin
            // Word access - enable all bytes
            ram_byteena = 4'b1111;
        end
    end

    // =============================================
    // Ready/Valid Logic
    // =============================================
    
    always_comb begin
        // Ready signals - can accept new requests when not pending and reset done
        read_ready = !read_request_pending && reset_done;
        write_ready = !write_request_pending && reset_done;
        
        // Enable RAM operations only for valid addresses and when ready
        ram_wren = we && address_valid && write_ready;
        ram_rden = re && address_valid && read_ready;
        
        // Data input handling for byte writes
        if (be) begin
            // Replicate byte data to all byte positions
            ram_data_in = {4{write_data[7:0]}};
        end else begin
            // Word write - pass data through
            ram_data_in = write_data;
        end
    end

    // =============================================
    // Read Request Pipeline Management
    // =============================================
    
    always_ff @(posedge clk) begin
        if (reset) begin
            read_pipe_valid <= '0;
            read_pipe_be <= '0;
            for (int i = 0; i < READ_LATENCY; i++) begin
                read_pipe_addr[i] <= '0;
            end
            read_request_pending <= 1'b0;
            write_request_pending <= 1'b0;
        end else if (reset_done) begin
            // Shift the read pipeline
            read_pipe_valid <= {read_pipe_valid[READ_LATENCY-2:0], ram_rden};
            read_pipe_be <= {read_pipe_be[READ_LATENCY-2:0], be};
            
            // Shift addresses in pipeline
            for (int i = READ_LATENCY-1; i > 0; i--) begin
                read_pipe_addr[i] <= read_pipe_addr[i-1];
            end
            read_pipe_addr[0] <= address;
            
            // Update pending flags
            read_request_pending <= ram_rden || (|read_pipe_valid[READ_LATENCY-2:0]);
            write_request_pending <= ram_wren;
        end
    end

    // =============================================
    // Output Data Handling with Latency
    // =============================================
    
    always_comb begin
        // Valid signal indicates when read data is available
        read_valid = read_pipe_valid[READ_LATENCY-1];
        
        if (read_valid) begin
            if (read_pipe_be[READ_LATENCY-1]) begin
                // Byte read - extract specific byte and zero-extend
                case (read_pipe_addr[READ_LATENCY-1][1:0])
                    2'b00: read_data = {24'h000000, ram_data_out[7:0]};
                    2'b01: read_data = {24'h000000, ram_data_out[15:8]};
                    2'b10: read_data = {24'h000000, ram_data_out[23:16]};
                    2'b11: read_data = {24'h000000, ram_data_out[31:24]};
                endcase
            end else begin
                // Word read - pass data through
                read_data = ram_data_out;
            end
        end else begin
            // Default output when not reading
            read_data = 32'h00000000;
        end
    end

    // =============================================
    // Reset Handling
    // =============================================
    
    // Since IP RAM doesn't have reset, we emulate reset behavior
    always_ff @(posedge clk) begin
        if (reset) begin
            reset_done <= 1'b0;
            reset_counter <= 16'h0000;
        end else begin
            if (reset_counter < 16'h0010) begin  // Shorter reset for faster sim
                reset_counter <= reset_counter + 1;
            end else begin
                reset_done <= 1'b1;
            end
        end
    end

    // =============================================
    // Performance Counters
    // =============================================
    
    always_ff @(posedge clk) begin
        if (reset) begin
            read_counter <= 32'h00000000;
            write_counter <= 32'h00000000;
            bytes_counter <= 32'h00000000;
        end else if (reset_done) begin
            // Count read operations when they complete (valid)
            if (read_valid) begin
                read_counter <= read_counter + 1;
                bytes_counter <= bytes_counter + (read_pipe_be[READ_LATENCY-1] ? 1 : 4);
            end
            
            // Count write operations immediately
            if (ram_wren) begin
                write_counter <= write_counter + 1;
                bytes_counter <= bytes_counter + (be ? 1 : 4);
            end
        end
    end
    
    // Output assignments
    assign read_count = read_counter;
    assign write_count = write_counter;
    assign bytes_transferred = bytes_counter;

    // =============================================
    // IP Catalog RAM Instantiation
    // =============================================
    
    ram ip_ram_inst (
        .address(ram_address),         // 13-bit address
        .byteena(ram_byteena),         // 4-bit byte enable
        .clock(clk),                   // System clock
        .data(ram_data_in),            // 32-bit write data
        .rden(ram_rden),               // Read enable
        .wren(ram_wren),               // Write enable
        .q(ram_data_out)               // 32-bit read data
    );

    // =============================================
    // Assertions for Debug
    // =============================================
    
    `ifdef ENABLE_ASSERTIONS
    
    // Check that read_valid is only high when expected
    always_ff @(posedge clk) begin
        if (!reset && read_valid) begin
            assert (read_pipe_valid[READ_LATENCY-1])
                else $error("read_valid high but no valid request in pipeline");
        end
    end
    
    // Check address alignment for word accesses
    always_ff @(posedge clk) begin
        if (!reset && !be && (we || re)) begin
            assert (address[1:0] == 2'b00) 
                else $error("Word access must be 4-byte aligned! Address: 0x%08x", address);
        end
    end
    
    // Check address bounds
    always_ff @(posedge clk) begin
        if (!reset && (we || re)) begin
            assert (address < (MEM_SIZE * 4))
                else $error("Address out of bounds! Address: 0x%08x, Max: 0x%08x", 
                           address, MEM_SIZE * 4 - 1);
        end
    end
    
    `endif

endmodule