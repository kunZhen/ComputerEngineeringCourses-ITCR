// Testbench for Processing Element module
// Comprehensive verification with edge cases and automatic checking
module processing_element_tb;

    // Parameters
    localparam CLK_PERIOD = 10;  // Clock period in ns
    localparam TEST_DELAY = 1;   // Delay after clock edge for signal stability

    // Signals
    logic               clk;
    logic               reset;
    logic               enable;
    logic               load_weight;
    logic signed [15:0] input_data;
    logic signed [15:0] weight_data;
    logic signed [31:0] partial_in;
    logic signed [31:0] partial_out;
	 logic [31:0]        mac_operations;
	 
	 logic signed [31:0] prev_output;

    // Instantiate Device Under Test (DUT)
    processing_element dut (
        .clk(clk),
        .reset(reset),
        .enable(enable),
        .load_weight(load_weight),
        .input_data(input_data),
        .weight_data(weight_data),
        .partial_in(partial_in),
        .partial_out(partial_out),
		  .mac_operations(mac_operations)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // Main test sequence
    initial begin
        $display("Starting Processing Element testbench...");
        
        // Initialize all inputs
        initialize_signals();
        apply_reset();
        
        // Test 1: Basic MAC operation (2 * 3 + 0 = 6)
        test_mac_operation(
            .weight(16'sd3),
            .input_val(16'sd2),
            .partial(32'sd0),
            .expected(32'sd6),
            .test_name("Basic MAC")
        );
        
        // Test 2: MAC with new weight (5 * -1 + 10 = 5)
        test_mac_operation(
            .weight(-16'sd1),
            .input_val(16'sd5),
            .partial(32'sd10),
            .expected(32'sd5),
            .test_name("Negative Weight MAC")
        );
        
        // Test 3: Clamping test (should clamp to 127)
        test_mac_operation(
            .weight(16'sd100),
            .input_val(16'sd2),
            .partial(32'sd10000),
            .expected(32'sd127),
            .test_name("Upper Clamp Test")
        );
        
        // Test 4: Clamping test (should clamp to -128)
        test_mac_operation(
            .weight(-16'sd100),
            .input_val(16'sd2),
            .partial(-32'sd10000),
            .expected(-32'sd128),
            .test_name("Lower Clamp Test")
        );
        
        // Test 5: Disabled operation (output shouldn't change)
        test_disabled_operation();
        
        $display("\n=== All tests completed successfully! ===\n");
        $finish;
    end

    // Helper task to initialize all signals
    task initialize_signals();
        reset = 0;
        enable = 0;
        load_weight = 0;
        input_data = 16'sd0;
        weight_data = 16'sd0;
        partial_in = 32'sd0;
        #(CLK_PERIOD);
    endtask

    // Helper task to apply and release reset
    task apply_reset();
        $display("Applying reset...");
        reset = 1;
        #(CLK_PERIOD);
        reset = 0;
        #(CLK_PERIOD);
    endtask

    // Task to test MAC operation with automatic verification
    task test_mac_operation(
        input logic signed [15:0] weight,
        input logic signed [15:0] input_val,
        input logic signed [31:0] partial,
        input logic signed [31:0] expected,
        input string test_name
    );
        $display("\nRunning test: %s", test_name);
        
        // Load weight
        load_weight = 1;
        weight_data = weight;
        #(CLK_PERIOD);
        load_weight = 0;
        
        // Apply inputs and enable
        input_data = input_val;
        partial_in = partial;
        enable = 1;
        #(CLK_PERIOD);
        enable = 0;
        
        // Verify result
        verify_output(expected, test_name);
    endtask

    // Task to test disabled operation
    task test_disabled_operation();
        $display("\nRunning test: Disabled Operation");
        
        // Store current output
        prev_output = partial_out;
        
        // Apply inputs without enable
        input_data = 16'sd100;
        partial_in = 32'sd1000;
        #(CLK_PERIOD);
        
        // Verify output didn't change
        if (partial_out !== prev_output) begin
            $error("Disabled operation failed: Output changed from %d to %d", 
                  prev_output, partial_out);
        end else begin
            $display("Disabled operation test passed");
        end
    endtask

    // Task to verify output with automatic checking
    task verify_output(
        input logic signed [31:0] expected,
        input string test_name
    );
        if (partial_out !== expected) begin
            $error("%s failed: Expected %d, Got %d", 
                  test_name, expected, partial_out);
        end else begin
            $display("%s passed: Output = %0d", test_name, partial_out);
        end
    endtask

endmodule
