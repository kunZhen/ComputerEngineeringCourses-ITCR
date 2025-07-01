// Processing Element
// Performs Multiply-Accumulate (MAC) operation with configurable weight
module processing_element (
    input  logic               clk,           // System clock
    input  logic               reset,         // Asynchronous reset (active high)
    input  logic               enable,        // PE enable signal
    input  logic               load_weight,   // Load new weight (active high)
    input  logic signed [15:0] input_data,    // Input data (16-bit signed)
    input  logic signed [15:0] weight_data,   // Weight data (16-bit signed)
    input  logic signed [31:0] partial_in,    // Input partial sum (32-bit signed)
    output logic signed [31:0] partial_out,   // Output partial sum (32-bit signed)
	 output logic [31:0]        mac_operations // MAC Operations Counter
);

    // Internal registers
    logic signed [15:0] weight_reg;           // Stored weight (16-bit signed)
    logic signed [31:0] partial_sum;          // Accumulated partial sum (32-bit signed)

    // Clamping function to prevent overflow
    // Clamps 32-bit values to range [-128, 127]
    function logic signed [31:0] clamp(input logic signed [31:0] value);
        // Using blocking assignment for function
        logic signed [31:0] clamped;
        begin
            if (value < -128) begin
                clamped = -128;
            end else if (value > 127) begin
                clamped = 127;
            end else begin
                clamped = value;
            end
            return clamped;
        end
    endfunction

    // Sequential logic for weight and partial sum updates
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            // Async reset initialization
            weight_reg   <= 16'sd0;
            partial_sum  <= 32'sd0;
				mac_operations <= 0;
        end else begin
            // Weight loading has priority when enabled
            if (load_weight) begin
                weight_reg <= weight_data;
            end
            
            // MAC operation when enabled
            if (enable) begin
                // Direct MAC without intermediate clamping for better performance
                partial_sum <= input_data * weight_reg + partial_in;
            end
				
				if (enable && !load_weight) begin
					 mac_operations <= mac_operations + 1;
				end
        end
    end

    // Output assignment with clamping
    assign partial_out = clamp(partial_sum);

endmodule
