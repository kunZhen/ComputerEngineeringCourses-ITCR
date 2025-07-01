// Systolic Array
// Implements a weight-stationary systolic array for matrix multiplication
module systolic_array #(
    parameter SIZE = 4,                // Array dimensions (SIZE x SIZE)
    parameter DATA_WIDTH = 16,         // Input data bit width
    parameter RESULT_WIDTH = 32        // Output result bit width
)(
    input logic clk,                   // System clock
    input logic reset,                 // Active-high asynchronous reset
    input logic enable,                // Global enable signal
    
    // Weight loading interface
    input logic load_weights,
    input logic [DATA_WIDTH-1:0] weight_data [0:SIZE-1][0:SIZE-1], 	 // Weight matrix
    
    // Data input interface  
    input logic [DATA_WIDTH-1:0] input_data [0:SIZE-1][0:SIZE-1],  	 // Input matrix
    
    // Output interface
    output logic [RESULT_WIDTH-1:0] output_data [0:SIZE-1][0:SIZE-1], // Result matrix
	 output logic [RESULT_WIDTH-1:0] total_mac_operations,  // Total MAC operations
    output logic [RESULT_WIDTH-1:0] total_cycles,          // Total processing cycles
    output logic done  												  // Operation complete flag
);

    // Internal signals
    logic [DATA_WIDTH-1:0] pe_input [0:SIZE-1][0:SIZE-1];          // PE input data
    logic [RESULT_WIDTH-1:0] pe_partial_in [0:SIZE-1][0:SIZE-1];   // PE partial sum in
    logic [RESULT_WIDTH-1:0] pe_partial_out [0:SIZE-1][0:SIZE-1];  // PE partial sum out
    logic [RESULT_WIDTH-1:0] result_buffer [0:SIZE-1][0:SIZE-1];   // Result buffer
	 logic [RESULT_WIDTH-1:0] pe_mac_ops [0:SIZE-1][0:SIZE-1];
    
    // Control signals
    logic [7:0] cycle_count;            // Processing cycle counter
    logic processing;                   // Active processing flag
    logic weights_loaded;               // Weights loaded flag
    logic capture_results;              // Result capture flag
    logic start_processing;             // Processing start pulse
    
    // =============================================
    // Processing Element Array Instantiation
    // =============================================
	 genvar i, j;
    generate
        for (i = 0; i < SIZE; i++) begin : pe_row
            for (j = 0; j < SIZE; j++) begin : pe_col
                processing_element pe (
                    .clk(clk),
                    .reset(reset),
                    .enable(processing),
                    .load_weight(load_weights),
                    .input_data(pe_input[i][j]),
                    .weight_data(weight_data[i][j]),
                    .partial_in(pe_partial_in[i][j]),
                    .partial_out(pe_partial_out[i][j]),
						  .mac_operations(pe_mac_ops[i][j])
                );
            end
        end
    endgenerate
    
    // =============================================
    // Data Routing Logic (Weight Stationary)
    // =============================================
    always_comb begin
        for (int row = 0; row < SIZE; row++) begin
            for (int col = 0; col < SIZE; col++) begin
                // Input data moves left to right through each row
                pe_input[row][col] = (col == 0) ? 
                    ((cycle_count >= row && cycle_count < row + SIZE) ? 
                     input_data[row][cycle_count - row] : '0) :
                    pe_input[row][col-1];
                
                // Partial results move bottom to top through each column
                pe_partial_in[row][col] = (row == SIZE-1) ? '0 : pe_partial_out[row+1][col];
            end
        end
    end
    
    // =============================================
    // Control Logic
    // =============================================
    
    // Edge detection for processing start
    logic enable_prev;
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            enable_prev <= 0;
        end else begin
            enable_prev <= enable;
        end
    end
    
    // Start processing when enabled with weights loaded
    assign start_processing = enable && !enable_prev && weights_loaded && !load_weights;
    
    // Main control state machine
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            cycle_count <= 0;
            processing <= 0;
            done <= 0;
            weights_loaded <= 0;
            capture_results <= 0;
				total_cycles <= 0;
        end else if (enable) begin
            // Weight loading has highest priority
            if (load_weights) begin
                weights_loaded <= 1;
                processing <= 0;
                done <= 0;
                cycle_count <= 0;
                capture_results <= 0;
            end 
            // Start new processing operation
            else if (start_processing) begin
                cycle_count <= 0;
                processing <= 1;
                done <= 0;
                capture_results <= 0;
            end 
            // Processing operation in progress
            else if (processing) begin
					 total_cycles <= total_cycles + 1;
                if (cycle_count < 2*SIZE - 1) begin
                    cycle_count <= cycle_count + 1;
                    
                    // Begin capturing results after pipeline fill
                    if (cycle_count >= SIZE-1) begin
                        capture_results <= 1;
                    end
                end else begin
                    // Processing complete
                    done <= 1;
                    processing <= 0;
                    capture_results <= 0;
                end
            end
        end else begin
            // Disabled state
            done <= 0;
            processing <= 0;
            capture_results <= 0;
        end
    end
    
    // =============================================
    // Result Capture and Output
    // =============================================
    
    // Capture results during valid cycles
    always_ff @(posedge clk) begin
        if (capture_results && processing) begin
            for (int i = 0; i < SIZE; i++) begin
                for (int j = 0; j < SIZE; j++) begin
                    result_buffer[i][j] <= pe_partial_out[i][j];
                end
            end
        end
    end
	 
	 // Count MAC operations by adding up all PEs
	 always_comb begin
		  automatic logic [31:0] sum = 0;
		  for (int i = 0; i < SIZE; i++) begin
			  for (int j = 0; j < SIZE; j++) begin
					sum += pe_mac_ops[i][j];
			  end
		  end
		  total_mac_operations = sum;
	 end
    
    // Output assignment with clamping and unsigned conversion
    always_comb begin
        for (int row = 0; row < SIZE; row++) begin
            for (int col = 0; col < SIZE; col++) begin
                automatic logic signed [RESULT_WIDTH-1:0] result = result_buffer[row][col];
                automatic logic signed [RESULT_WIDTH-1:0] clamped;
                
                // Clamp to [-128, 127] range
                clamped = (result < -128) ? -128 :
                         (result > 127) ? 127 : result;
                
                // Convert to unsigned by adding 128
                output_data[row][col] = clamped + 128;
            end
        end
    end

endmodule
