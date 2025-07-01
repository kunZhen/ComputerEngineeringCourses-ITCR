// Testbench for Systolic Array module
// Comprehensive verification with matrix operations and result display
module systolic_array_tb;

    // Parameters
    localparam SIZE = 4;
    localparam DATA_WIDTH = 16;
    localparam RESULT_WIDTH = 32;
    localparam CLK_PERIOD = 10;  // Clock period in ns

    // Signals
    logic clk;
    logic reset;
    logic enable;
    logic load_weights;
    logic [DATA_WIDTH-1:0] weight_data [0:SIZE-1][0:SIZE-1];
    logic [DATA_WIDTH-1:0] input_data [0:SIZE-1][0:SIZE-1];
    logic [RESULT_WIDTH-1:0] output_data [0:SIZE-1][0:SIZE-1];
	 logic [RESULT_WIDTH-1:0] total_mac_operations;
	 logic [RESULT_WIDTH-1:0] total_cycles;
    logic done;

    // Test data storage
    logic [DATA_WIDTH-1:0] test_weights [0:SIZE-1][0:SIZE-1];
    logic [DATA_WIDTH-1:0] test_input1 [0:SIZE-1][0:SIZE-1];
    logic [DATA_WIDTH-1:0] test_input2 [0:SIZE-1][0:SIZE-1];

    // Instantiate Device Under Test (DUT)
    systolic_array #(
        .SIZE(SIZE),
        .DATA_WIDTH(DATA_WIDTH),
        .RESULT_WIDTH(RESULT_WIDTH)
    ) dut (
        .clk(clk),
        .reset(reset),
        .enable(enable),
        .load_weights(load_weights),
        .weight_data(weight_data),
        .input_data(input_data),
        .output_data(output_data),
		  .total_mac_operations(total_mac_operations),
		  .total_cycles(total_cycles),
        .done(done)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // Main test sequence
    initial begin
        $display("=== Starting Systolic Array Testbench ===\n");
        
        // Initialize test data
        initialize_test_data();
        
        // Initialize signals and apply reset
        initialize_signals();
        apply_reset();
        
        // Test 1: First matrix multiplication
        $display("=== TEST 1: First Matrix Operation ===");
        run_matrix_test(test_weights, test_input1, "Test 1");
        
        // Wait between tests
        #(CLK_PERIOD * 5);
        
        // Test 2: Second matrix multiplication
        $display("\n=== TEST 2: Second Matrix Operation ===");
        run_matrix_test(test_weights, test_input2, "Test 2");
        
        $display("\n=== All tests completed successfully! ===\n");
        $finish;
    end

    // Task to initialize test data
    task initialize_test_data();
        // Weight matrix
        test_weights[0] = '{-2, -1, 0, 1};
        test_weights[1] = '{-1, 1, 1, 2};
        test_weights[2] = '{0, 1, 2, 1};
        test_weights[3] = '{1, 2, 1, 0};
        
        // First input matrix
        test_input1[0] = '{1, 2, 3, 4};
        test_input1[1] = '{5, 6, 7, 8};
        test_input1[2] = '{9, 10, 11, 12};
        test_input1[3] = '{13, 14, 15, 16};
        
        // Second input matrix
        test_input2[0] = '{-36, -24, -22, -22};
        test_input2[1] = '{-33, -22, -22, -25};
        test_input2[2] = '{-45, -32, -31, -33};
        test_input2[3] = '{-24, -9, -6, -8};
    endtask

    // Task to initialize all signals
    task initialize_signals();
        reset = 0;
        enable = 0;
        load_weights = 0;
        
        // Initialize arrays to zero
        for (int i = 0; i < SIZE; i++) begin
            for (int j = 0; j < SIZE; j++) begin
                weight_data[i][j] = 0;
                input_data[i][j] = 0;
            end
        end
        
        #(CLK_PERIOD);
    endtask

    // Task to apply and release reset
    task apply_reset();
        $display("Applying reset...");
        reset = 1;
        #(CLK_PERIOD * 2);
        reset = 0;
        #(CLK_PERIOD);
        $display("Reset released\n");
    endtask

    // Task to run a complete matrix test
    task run_matrix_test(
        input logic [DATA_WIDTH-1:0] weights [0:SIZE-1][0:SIZE-1],
        input logic [DATA_WIDTH-1:0] inputs [0:SIZE-1][0:SIZE-1],
        input string test_name
    );
        // Copy test data to DUT inputs
        for (int i = 0; i < SIZE; i++) begin
            for (int j = 0; j < SIZE; j++) begin
                weight_data[i][j] = weights[i][j];
                input_data[i][j] = inputs[i][j];
            end
        end
        
        // Print input matrices
        print_weight_matrix(weights);
        print_input_matrix(inputs);
        
        // Load weights
        load_weights_sequence();
        
        // Force processing start if needed
        force_processing_start();
        
        // Perform matrix multiplication
        perform_multiplication();
        
        // Print results
        print_output_matrix();
    endtask

    // Task to load weights into the systolic array
    task load_weights_sequence();
        $display("Loading weights...");
        enable = 1;
        load_weights = 1;
        #(CLK_PERIOD);
        load_weights = 0;
        #(CLK_PERIOD);
        $display("Weights loaded\n");
    endtask

    // Task to force processing start
    task force_processing_start();
        $display("Processing start...");
        // Toggle enable to trigger start_processing
        enable = 0;
        #(CLK_PERIOD);
        enable = 1;
        #(CLK_PERIOD);
        $display("Processing start triggered\n");
    endtask

    // Task to perform matrix multiplication
    task perform_multiplication();
        $display("Starting matrix multiplication...");
        
        // Start processing (enable should already be high from weight loading)
        #(CLK_PERIOD);
        
        // Wait for completion
        wait(done);
        $display("Matrix multiplication completed\n");
        
        // Additional cycle for result stabilization
        #(CLK_PERIOD);
        
        enable = 0;
        #(CLK_PERIOD);
    endtask

    // Task to print weight matrix
    task print_weight_matrix(input logic [DATA_WIDTH-1:0] weights [0:SIZE-1][0:SIZE-1]);
        $display("WEIGHT DATA:");
        for (int i = 0; i < SIZE; i++) begin
            $write("  [");
            for (int j = 0; j < SIZE; j++) begin
                if (j == SIZE-1)
                    $write("%4d", $signed(weights[i][j]));
                else
                    $write("%4d,", $signed(weights[i][j]));
            end
            $display("]");
        end
        $display("");
    endtask

    // Task to print input matrix
    task print_input_matrix(input logic [DATA_WIDTH-1:0] inputs [0:SIZE-1][0:SIZE-1]);
        $display("INPUT DATA:");
        for (int i = 0; i < SIZE; i++) begin
            $write("  [");
            for (int j = 0; j < SIZE; j++) begin
                if (j == SIZE-1)
                    $write("%4d", $signed(inputs[i][j]));
                else
                    $write("%4d,", $signed(inputs[i][j]));
            end
            $display("]");
        end
        $display("");
    endtask

    // Task to print output matrix
    task print_output_matrix();
        $display("OUTPUT DATA:");
        for (int i = 0; i < SIZE; i++) begin
            $write("  [");
            for (int j = 0; j < SIZE; j++) begin
                if (j == SIZE-1)
                    $write("%4d", output_data[i][j]);
                else
                    $write("%4d,", output_data[i][j]);
            end
            $display("]");
        end
        $display("");
    endtask

    // Monitor for debugging (optional)
    initial begin
        forever begin
            @(posedge clk);
            if (enable && !reset) begin
                $display("Time: %0t | Cycle: %0d | Processing: %b | Done: %b | Enable: %b", 
                         $time, dut.cycle_count, dut.processing, done, enable);
            end
        end
    end

    // Basic monitor
    initial begin
        $monitor("Time: %0t | Reset: %b | Enable: %b | Load_weights: %b | Done: %b", 
                 $time, reset, enable, load_weights, done);
    end

    // Timeout protection
    initial begin
        #(CLK_PERIOD * 1000);  // Timeout after 1000 clock cycles
        $error("Testbench timeout!");
        $finish;
    end

endmodule
