/**
 * Image Processor Modificado para Manejar Latencia de RAM IP
 * 
 * Cambios principales:
 * - Estados de espera para operaciones de lectura
 * - Uso de señales read_valid/read_ready
 * - Pipeline de lecturas para mantener throughput
 * - Compatibilidad con memory_wrapper con latencia
 */

module image_processor #(
    parameter DATA_WIDTH = 16,       // Width of input data (signed)
    parameter RESULT_WIDTH = 32,     // Width of processed results
    parameter BLOCK_SIZE = 4,        // Size of processing blocks (BLOCK_SIZE x BLOCK_SIZE)
    parameter ADDRESS_WIDTH = 32,    // Width of memory addresses
    parameter MEM_SIZE = 8192,       // Size of main memory
    parameter WEIGHTS_ADDR = 32'h00000000,  // Base address for weights
    parameter INPUT_ADDR = 32'h00000020,    // Base address for input image
    parameter OUTPUT_ADDR = 32'h00001000    // Base address for output image
)(
    // Clock and reset
    input logic clk,
    input logic reset,
    
    // Control signals
    input logic start,               // Start processing
    output logic done,               // Processing complete
    
    // Debug outputs
    output logic [31:0] debug_width,      // Current image width
    output logic [31:0] debug_height,     // Current image height
    output logic [7:0] debug_block_row,   // Current block row
    output logic [7:0] debug_block_col,   // Current block column
    output logic [3:0] debug_state,       // Current FSM state
    output logic processing_complete,     // Processing completion flag
	 
	 // Performance counters
	 output logic [31:0] total_mem_accesses,
	 output logic [31:0] total_bytes_transferred,
	 output logic [31:0] total_mac_operations,
	 output logic [31:0] total_processing_cycles
);

    // =============================================
    // FSM State Definitions (UPDATED)
    // =============================================
    typedef enum logic [3:0] {
        IDLE = 4'd0,                        // Waiting for start signal
        READ_IMG_DIMENSIONS = 4'd1,         // Reading image dimensions from memory
        WAIT_IMG_DIMENSIONS = 4'd2,         // Wait for dimension read to complete
        LOAD_WEIGHTS = 4'd3,                // Loading weight dimensions
        WAIT_WEIGHTS_DIM = 4'd4,            // Wait for weight dimensions
        LOAD_WEIGHTS_DATA = 4'd5,           // Loading weight values
        WAIT_WEIGHTS_DATA = 4'd6,           // Wait for weight data
        READ_INPUT_BLOCK = 4'd7,            // Reading input image block
        WAIT_INPUT_BLOCK = 4'd8,            // Wait for input block read
        PROCESS_BLOCK = 4'd9,               // Start processing block
        WAIT_PROCESSING = 4'd10,            // Wait for processing to complete
        WRITE_OUTPUT_BLOCK = 4'd11,         // Write processed block to memory
        NEXT_BLOCK = 4'd12,                 // Move to next block
        WRITE_OUTPUT_DIMENSIONS = 4'd13,    // Write output dimensions
        DONE_STATE = 4'd14                  // Processing complete
    } state_t;

    // State registers
    state_t current_state, next_state;

    // =============================================
    // Memory Interface Signals (UPDATED)
    // =============================================
    logic [ADDRESS_WIDTH-1:0] mem_address;
    logic [31:0] mem_write_data;
    logic [31:0] mem_read_data;
    logic [31:0] mem_read_count;
    logic [31:0] mem_write_count;
    logic [31:0] mem_bytes_transferred;
    logic mem_we;       // Write enable
    logic mem_re;       // Read enable
    logic mem_be;       // Byte enable
    
    // NEW: Handshaking signals
    logic mem_read_valid;    // Read data is valid
    logic mem_read_ready;    // Ready to accept new read request
    logic mem_write_ready;   // Ready to accept new write request

    // =============================================
    // Image and Processing Parameters
    // =============================================
    logic [31:0] image_width, image_height;     // Input image dimensions
    logic [31:0] weight_width, weight_height;   // Weight matrix dimensions
    
    // Current block dimensions (may be smaller than BLOCK_SIZE at edges)
    logic [31:0] current_block_height, current_block_width;
    
    // Block processing counters
    logic [31:0] block_row, block_col;  // Current block position
    logic [7:0] pixel_row, pixel_col;   // Current pixel within block
    logic [7:0] byte_index;             // Byte index for memory operations
    
    // =============================================
    // Data Buffers
    // =============================================
    logic [DATA_WIDTH-1:0] input_block [0:BLOCK_SIZE-1][0:BLOCK_SIZE-1];
    logic [DATA_WIDTH-1:0] weight_data [0:BLOCK_SIZE-1][0:BLOCK_SIZE-1];
    logic [RESULT_WIDTH-1:0] output_block [0:BLOCK_SIZE-1][0:BLOCK_SIZE-1];
    
    // =============================================
    // Systolic Array Interface
    // =============================================
    logic sa_enable;                    // Enable processing
    logic sa_load_weights;              // Load weight signal
    logic sa_done;                      // Processing complete
    
    // Data connections
    logic [DATA_WIDTH-1:0] sa_input_data [0:BLOCK_SIZE-1][0:BLOCK_SIZE-1];
    logic [RESULT_WIDTH-1:0] sa_output_data [0:BLOCK_SIZE-1][0:BLOCK_SIZE-1];
    logic [RESULT_WIDTH-1:0] sa_total_mac_operations;
    logic [RESULT_WIDTH-1:0] sa_total_cycles;
    
    // Temporary storage
    logic [31:0] output_word;           // Packed output word (4 pixels)
    logic [31:0] pixel_addr;            // Current pixel address
    
    // Processing completion flag
    logic processing_complete_internal;
    
    // =============================================
    // Operation Counters (UPDATED)
    // =============================================
    logic [7:0] mem_op_count;           // Memory operation counter
    logic [7:0] weight_load_count;      // Weight loading counter
    logic [7:0] pixels_per_row;         // Pixels processed per row
    logic [7:0] read_wait_count;        // Counter for read waits

    // =============================================
    // Module Instantiations
    // =============================================
    
    // Memory subsystem with latency handling
    memory_wrapper #(
        .DATA_WIDTH(32),
        .ADDRESS_WIDTH(ADDRESS_WIDTH),
        .MEM_SIZE(MEM_SIZE),
        .READ_LATENCY(2)                // Configure based on your RAM IP
    ) mem_inst (
        .clk(clk),
        .reset(reset),
        .address(mem_address),
        .write_data(mem_write_data),
        .we(mem_we),
        .re(mem_re),
        .be(mem_be),
        .read_data(mem_read_data),
        .read_valid(mem_read_valid),
        .read_ready(mem_read_ready),
        .write_ready(mem_write_ready),
        .read_count(mem_read_count),
        .write_count(mem_write_count),
        .bytes_transferred(mem_bytes_transferred)
    );
    
    // Systolic array processing unit
    systolic_array #(
        .SIZE(BLOCK_SIZE),
        .DATA_WIDTH(DATA_WIDTH),
        .RESULT_WIDTH(RESULT_WIDTH)
    ) sa_inst (
        .clk(clk),
        .reset(reset),
        .enable(sa_enable),
        .load_weights(sa_load_weights),
        .weight_data(weight_data),
        .input_data(sa_input_data),
        .output_data(sa_output_data),
        .total_mac_operations(sa_total_mac_operations),
        .total_cycles(sa_total_cycles),
        .done(sa_done)
    );

    // =============================================
    // Data Conversion Functions (UNCHANGED)
    // =============================================
    
    function logic signed [DATA_WIDTH-1:0] uint8_to_int16(input logic [7:0] pixel);
        return $signed({8'h00, pixel}) - 128;
    endfunction

    function logic [7:0] int32_to_uint8(input logic signed [RESULT_WIDTH-1:0] value);
        return value[7:0];
    endfunction

    function logic [7:0] extract_pixel_from_word(input logic [31:0] word, input logic [1:0] byte_offset);
        case (byte_offset)
            2'b00: return word[7:0];   // byte 0 (least significant)
            2'b01: return word[15:8];  // byte 1
            2'b10: return word[23:16]; // byte 2
            2'b11: return word[31:24]; // byte 3 (most significant)
        endcase
    endfunction

    // =============================================
    // Combinational Logic
    // =============================================
    
    // Calculate current block dimensions (may be smaller at image edges)
    always_comb begin
        current_block_height = (block_row + BLOCK_SIZE > image_height) ? 
                             (image_height - block_row) : BLOCK_SIZE;
        current_block_width = (block_col + BLOCK_SIZE > image_width) ? 
                            (image_width - block_col) : BLOCK_SIZE;
    end

    // Debug outputs
    assign debug_width = image_width;
    assign debug_height = image_height;
    assign debug_block_row = block_row[7:0];
    assign debug_block_col = block_col[7:0];
    assign debug_state = current_state;
    assign processing_complete = processing_complete_internal;
	 
	 // Connect the systolic array and memory signals
	 assign total_mac_operations = sa_total_mac_operations;
	 assign total_processing_cycles = sa_total_cycles;
	 assign total_mem_accesses = mem_read_count + mem_write_count;
	 assign total_bytes_transferred = mem_bytes_transferred;

    // Connect input block to systolic array
    always_comb begin
        for (int i = 0; i < BLOCK_SIZE; i++) begin
            for (int j = 0; j < BLOCK_SIZE; j++) begin
                sa_input_data[i][j] = input_block[i][j];
            end
        end
    end

    // =============================================
    // Sequential Logic - FSM and Data Processing (UPDATED)
    // =============================================
    always_ff @(posedge clk or posedge reset) begin
		 if (reset) begin
			  // Reset all state
			  current_state <= IDLE;
			  image_width <= 0;
			  image_height <= 0;
			  weight_width <= 0;
			  weight_height <= 0;
			  block_row <= 0;
			  block_col <= 0;
			  pixel_row <= 0;
			  pixel_col <= 0;
			  byte_index <= 0;
			  mem_op_count <= 0;
			  weight_load_count <= 0;
			  pixels_per_row <= 0;
			  read_wait_count <= 0;
			  done <= 0;  // ✅ Reset done en reset
			  processing_complete_internal <= 0;
			  
			  // Initialize all data arrays to zero
			  for (int i = 0; i < BLOCK_SIZE; i++) begin
					for (int j = 0; j < BLOCK_SIZE; j++) begin
						 input_block[i][j] <= 0;
						 weight_data[i][j] <= 0;
						 output_block[i][j] <= 0;
					end
			  end
		 end else begin
			  current_state <= next_state;
			  
			  // =============================================
			  // NUEVO: Manejo persistente de done
			  // =============================================
			  if (start) begin
					done <= 0;  // Reset done cuando inicia nuevo procesamiento
			  end else if (current_state == DONE_STATE) begin
					done <= 1;  // Set done cuando termina, mantener hasta nuevo start
			  end
			  // NO resetear done en ningún otro lugar
			  
			  // State-specific processing
			  case (current_state)
					WAIT_IMG_DIMENSIONS: begin
						 // Wait for image dimensions to be read
						 if (mem_read_valid) begin
							  if (mem_op_count == 0) begin
									image_width <= mem_read_data;
									mem_op_count <= 1;
							  end else if (mem_op_count == 1) begin
									image_height <= mem_read_data;
									mem_op_count <= 0;
							  end
						 end
					end
					
					WAIT_WEIGHTS_DIM: begin
						 // Wait for weight dimensions to be read
						 if (mem_read_valid) begin
							  if (mem_op_count == 0) begin
									weight_width <= mem_read_data;
									mem_op_count <= 1;
							  end else if (mem_op_count == 1) begin
									weight_height <= mem_read_data;
									mem_op_count <= 0;
									weight_load_count <= 0;
							  end
						 end
					end
					
					WAIT_WEIGHTS_DATA: begin
						 // Wait for weight values to be read
						 if (mem_read_valid && weight_load_count < BLOCK_SIZE) begin
							  // Each 32-bit word contains 4 weights (one row)
							  automatic logic [31:0] weight_word = mem_read_data;
							  automatic int row_idx = weight_load_count;

							  for (int i = 0; i < BLOCK_SIZE; i++) begin
									// Extract weights from MSB to LSB
									automatic logic [7:0] weight_byte = weight_word[(3 - i)*8 +: 8];
									weight_data[row_idx][i] <= $signed(weight_byte);
							  end
							  weight_load_count <= weight_load_count + 1;
						 end
					end
					
					WAIT_INPUT_BLOCK: begin
						 // Wait for input block pixels to be read
						 if (mem_read_valid) begin
							  if (pixel_row < current_block_height && pixel_col < current_block_width) begin
									// Extract and convert pixel from read data
									automatic logic [31:0] pixel_word = mem_read_data;
									automatic logic [31:0] base_pixel_addr = INPUT_ADDR + 8 + 
															  (block_row + pixel_row) * image_width + 
															  (block_col + pixel_col);
									automatic logic [1:0] byte_offset = base_pixel_addr[1:0];
									automatic logic [7:0] pixel_byte = extract_pixel_from_word(pixel_word, byte_offset);
									
									// Convert and store pixel
									input_block[pixel_row][pixel_col] <= uint8_to_int16(pixel_byte);
							  end else begin
									// Pad unused pixels with -128 (zero after conversion)
									input_block[pixel_row][pixel_col] <= -128;
							  end
							  
							  // Advance to next pixel
							  if (pixel_col < BLOCK_SIZE - 1) begin
									pixel_col <= pixel_col + 1;
							  end else begin
									pixel_col <= 0;
									if (pixel_row < BLOCK_SIZE - 1) begin
										 pixel_row <= pixel_row + 1;
									end else begin
										 pixel_row <= 0;
										 mem_op_count <= 0;
									end
							  end
						 end
					end
					
					WAIT_PROCESSING: begin
						 // Wait for systolic array to complete processing
						 if (sa_done) begin
							  // Store results
							  for (int i = 0; i < BLOCK_SIZE; i++) begin
									for (int j = 0; j < BLOCK_SIZE; j++) begin
										 output_block[i][j] <= sa_output_data[i][j];
									end
							  end
							  // Reset pixel counters for writing
							  pixel_row <= 0;
							  pixel_col <= 0;
							  pixels_per_row <= 0;
						 end
					end
					
					WRITE_OUTPUT_BLOCK: begin
						 // Write processed block to memory (no wait needed for writes)
						 if (pixel_row < current_block_height) begin
							  if (pixels_per_row + 4 <= current_block_width) begin
									// Process 4 pixels at a time (pack into 32-bit word)
									pixels_per_row <= pixels_per_row + 4;
							  end else begin
									// Move to next row
									pixels_per_row <= 0;
									pixel_row <= pixel_row + 1;
							  end
						 end else begin
							  // Done writing this block
							  pixel_row <= 0;
							  pixels_per_row <= 0;
							  mem_op_count <= 0;
						 end
					end
					
					NEXT_BLOCK: begin
						 // Move to next block in image
						 if (block_col + BLOCK_SIZE >= image_width) begin
							  // Move to next row of blocks
							  block_col <= 0;
							  if (block_row + BLOCK_SIZE >= image_height) begin
									// Done with all blocks - set completion flag
									processing_complete_internal <= 1;
									block_row <= 0;
									block_col <= 0;
									mem_op_count <= 0;  // Reset for dimension writing
							  end else begin
									block_row <= block_row + BLOCK_SIZE;
							  end
						 end else begin
							  // Move to next column
							  block_col <= block_col + BLOCK_SIZE;
						 end
						 // Reset counters
						 pixel_row <= 0;
						 pixel_col <= 0;
					end
					
					WRITE_OUTPUT_DIMENSIONS: begin
						 // Write output image dimensions synchronized with memory writes
						 if (mem_write_ready && mem_op_count < 2) begin
							  // Only increment counter when actually writing
							  mem_op_count <= mem_op_count + 1;
						 end
					end
					
					// DONE_STATE: No hacer nada especial, done ya está manejado arriba
			  endcase
		 end
	end

    // =============================================
    // FSM Combinational Logic - Next State and Memory Control (UPDATED)
    // =============================================
    always_comb begin
        // Default values
        next_state = current_state;
        mem_address = 0;
        mem_write_data = 0;
        mem_we = 0;
        mem_re = 0;
        mem_be = 0;
        sa_enable = 0;
        sa_load_weights = 0;
        output_word = 0;
        pixel_addr = 0;
        
        case (current_state)
            IDLE: begin
                if (start) begin
                    next_state = READ_IMG_DIMENSIONS;
                end
            end
            
            READ_IMG_DIMENSIONS: begin
                // Issue read request and immediately transition to wait state
                if (mem_read_ready) begin
                    mem_re = 1;
                    if (mem_op_count == 0) begin
                        mem_address = INPUT_ADDR;
                        next_state = WAIT_IMG_DIMENSIONS;
                    end else begin
                        mem_address = INPUT_ADDR + 4;
                        next_state = WAIT_IMG_DIMENSIONS;
                    end
                end
            end
            
            WAIT_IMG_DIMENSIONS: begin
                // Wait for read to complete, then decide next action
                if (mem_read_valid) begin
                    if (mem_op_count == 1) begin
                        next_state = LOAD_WEIGHTS;
                    end else begin
                        next_state = READ_IMG_DIMENSIONS;  // Read second dimension
                    end
                end
            end
            
            LOAD_WEIGHTS: begin
                // Issue weight dimension read requests
                if (mem_read_ready) begin
                    mem_re = 1;
                    if (mem_op_count == 0) begin
                        mem_address = WEIGHTS_ADDR;
                        next_state = WAIT_WEIGHTS_DIM;
                    end else begin
                        mem_address = WEIGHTS_ADDR + 4;
                        next_state = WAIT_WEIGHTS_DIM;
                    end
                end
            end
            
            WAIT_WEIGHTS_DIM: begin
                // Wait for weight dimensions, then start loading data
                if (mem_read_valid) begin
                    if (mem_op_count == 1) begin
                        next_state = LOAD_WEIGHTS_DATA;
                    end else begin
                        next_state = LOAD_WEIGHTS;  // Read second dimension
                    end
                end
            end
            
            LOAD_WEIGHTS_DATA: begin
                // Issue weight data read requests
                if (mem_read_ready) begin
                    mem_re = 1;
                    mem_address = WEIGHTS_ADDR + 8 + weight_load_count * 4;
                    next_state = WAIT_WEIGHTS_DATA;
                end
            end
            
            WAIT_WEIGHTS_DATA: begin
                // Wait for weight data, check if done
                if (mem_read_valid && weight_load_count >= BLOCK_SIZE) begin
                    // Done loading weights - start systolic array
                    sa_load_weights = 1;
                    sa_enable = 1;
                    next_state = READ_INPUT_BLOCK;
                end else if (mem_read_valid) begin
                    // Continue loading more weights
                    next_state = LOAD_WEIGHTS_DATA;
                end
            end
            
            READ_INPUT_BLOCK: begin
                // Issue input block read requests
                if (mem_read_ready && pixel_row < current_block_height && pixel_col < current_block_width) begin
                    mem_re = 1;
                    // Calculate word-aligned address
                    pixel_addr = INPUT_ADDR + 8 + 
                                (block_row + pixel_row) * image_width + 
                                (block_col + pixel_col);
                    mem_address = pixel_addr & ~32'h3;
                    next_state = WAIT_INPUT_BLOCK;
                end else if (pixel_row >= BLOCK_SIZE - 1 && pixel_col >= BLOCK_SIZE - 1) begin
                    next_state = PROCESS_BLOCK;
                end
            end
            
            WAIT_INPUT_BLOCK: begin
                // Wait for input data, check if block is complete
                if (mem_read_valid) begin
                    if (pixel_row >= BLOCK_SIZE - 1 && pixel_col >= BLOCK_SIZE - 1) begin
                        next_state = PROCESS_BLOCK;
                    end else begin
                        next_state = READ_INPUT_BLOCK;  // Continue reading block
                    end
                end
            end
            
            PROCESS_BLOCK: begin
                sa_enable = 1;
                next_state = WAIT_PROCESSING;
            end
            
            WAIT_PROCESSING: begin
                sa_enable = 1;
                if (sa_done) begin
                    next_state = WRITE_OUTPUT_BLOCK;
                end
            end
            
            WRITE_OUTPUT_BLOCK: begin
                sa_enable = 0;  // Disable systolic array during write
                
                // Only write valid pixels (writes are immediate, no latency)
                if (pixel_row < current_block_height && pixels_per_row < current_block_width && mem_write_ready) begin
                    mem_we = 1;
                    // Calculate output address
                    mem_address = OUTPUT_ADDR + 8 + 
                                 (block_row + pixel_row) * image_width + 
                                 (block_col + pixels_per_row);
                    
                    // Pack up to 4 output pixels into one word
                    output_word = 0;
                    for (int k = 0; k < 4; k++) begin
                        if (pixels_per_row + k < current_block_width) begin
                            automatic logic [7:0] pixel8 = 
                                int32_to_uint8(output_block[pixel_row][pixels_per_row + k]);
                            output_word[k*8 +: 8] = pixel8;
                        end
                    end
                    mem_write_data = output_word;
                end
                
                // Check if we've written all pixels in this block
                if (pixel_row >= current_block_height - 1 && 
                    pixels_per_row + 4 >= current_block_width) begin
                    next_state = NEXT_BLOCK;
                end
            end
            
            NEXT_BLOCK: begin
                sa_enable = 0;
                
                // Check if we've processed all blocks using completion flag
                if (processing_complete_internal) begin
                    // All blocks processed
                    next_state = WRITE_OUTPUT_DIMENSIONS;
                end else begin
                    // Continue processing more blocks
                    next_state = READ_INPUT_BLOCK;
                end
            end
            
            WRITE_OUTPUT_DIMENSIONS: begin
                if (mem_write_ready && mem_op_count < 2) begin
                    mem_we = 1;
                    if (mem_op_count == 0) begin
                        mem_address = OUTPUT_ADDR;
                        mem_write_data = image_width;
                    end else if (mem_op_count == 1) begin
                        mem_address = OUTPUT_ADDR + 4;
                        mem_write_data = image_height;
                    end
                end else if (mem_op_count >= 2) begin
                    // Both dimensions written, transition to done
                    next_state = DONE_STATE;
                end
            end
            
            DONE_STATE: begin
					  // Stay in done state until new start
					  if (start) begin
							next_state = READ_IMG_DIMENSIONS;  // Restart
					  end else begin
							next_state = DONE_STATE;  // Stay done
					  end
				 end
        endcase
    end

endmodule