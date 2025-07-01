// =============================================
    // Timeout Protection (INCREASED for Latency)
    // =============================================
	 /**
 * Image Processor Testbench - Actualizado para Manejo de Latencia
 * 
 * Cambios principales:
 * - Uso de read_valid para sincronización
 * - Tasks actualizadas para manejar latencia
 * - Timeouts ajustados para mayor latencia
 * - Mejor monitoreo de pipeline de memoria
 */

module image_processor_tb;
    timeunit 1ns;           // Agregar timeunit para evitar warnings
    timeprecision 1ps;

    // =============================================
    // Test Parameters
    // =============================================
    localparam CLK_PERIOD = 10;                // Clock period in ns
    localparam DATA_WIDTH = 16;                // Data width for processing
    localparam RESULT_WIDTH = 32;              // Result width after processing
    localparam BLOCK_SIZE = 4;                 // Processing block size
    localparam ADDRESS_WIDTH = 32;             // Memory address width
    localparam MEM_SIZE = 8192;                // Memory size in words
    
    // Memory address mapping
    localparam WEIGHTS_ADDR = 32'h00000000;    // Base address for weights
    localparam INPUT_ADDR = 32'h00000020;      // Base address for input image
    localparam OUTPUT_ADDR = 32'h00002800;     // Base address for output image
    
    // Testbench variables
    logic [31:0] temp_data;                    // Temporary data storage
    integer file_handle;                       // File handle for output

    // =============================================
    // DUT Interface Signals
    // =============================================
    logic clk;                                 // System clock
    logic reset;                               // Active-high reset
    logic start;                               // Start processing signal
    logic done;                                // Processing complete signal
    
    // Debug signals
    logic [31:0] debug_width;                  // Current image width
    logic [31:0] debug_height;                 // Current image height
    logic [7:0] debug_block_row;               // Current block row
    logic [7:0] debug_block_col;               // Current block column
    logic [3:0] debug_state;                   // Current FSM state
    logic processing_complete;                 // Processing completion flag
	 
	 // Performance counters
	 logic [31:0] total_mem_accesses;
	 logic [31:0] total_bytes_transferred;
	 logic [31:0] total_mac_operations;
	 logic [31:0] total_processing_cycles;

    // =============================================
    // DUT Instantiation
    // =============================================
    image_processor #(
        .DATA_WIDTH(DATA_WIDTH),
        .RESULT_WIDTH(RESULT_WIDTH),
        .BLOCK_SIZE(BLOCK_SIZE),
        .ADDRESS_WIDTH(ADDRESS_WIDTH),
        .MEM_SIZE(MEM_SIZE),
        .WEIGHTS_ADDR(WEIGHTS_ADDR),
        .INPUT_ADDR(INPUT_ADDR),
        .OUTPUT_ADDR(OUTPUT_ADDR)
    ) dut (
        .clk(clk),
        .reset(reset),
        .start(start),
        .done(done),
        .debug_width(debug_width),
        .debug_height(debug_height),
        .debug_block_row(debug_block_row),
        .debug_block_col(debug_block_col),
        .debug_state(debug_state),
        .processing_complete(processing_complete),
		  .total_mem_accesses(total_mem_accesses),
		  .total_bytes_transferred(total_bytes_transferred),
		  .total_mac_operations(total_mac_operations),
		  .total_processing_cycles(total_processing_cycles)
    );

    // =============================================
    // Clock Generation
    // =============================================
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // =============================================
    // Helper Functions (UPDATED for Latency)
    // =============================================
    
    function string get_state_name(input [3:0] state);
        case (state)
            4'd0:  return "IDLE";
            4'd1:  return "READ_IMG_DIMENSIONS";
            4'd2:  return "WAIT_IMG_DIMENSIONS";
            4'd3:  return "LOAD_WEIGHTS";
            4'd4:  return "WAIT_WEIGHTS_DIM";
            4'd5:  return "LOAD_WEIGHTS_DATA";
            4'd6:  return "WAIT_WEIGHTS_DATA";
            4'd7:  return "READ_INPUT_BLOCK";
            4'd8:  return "WAIT_INPUT_BLOCK";
            4'd9:  return "PROCESS_BLOCK";
            4'd10: return "WAIT_PROCESSING";
            4'd11: return "WRITE_OUTPUT_BLOCK";
            4'd12: return "NEXT_BLOCK";
            4'd13: return "WRITE_OUTPUT_DIMENSIONS";
            4'd14: return "DONE_STATE";
            default: return "UNKNOWN";
        endcase
    endfunction
     
    /**
     * Read memory word with latency handling
     * Now waits for read_valid signal
     */
    task read_memory_word(input logic [31:0] address, output logic [31:0] data);
        automatic int timeout_counter = 0;
        
        // Wait for memory to be ready
        while (!dut.mem_inst.read_ready && timeout_counter < 100) begin
            @(posedge clk);
            timeout_counter++;
        end
        
        if (timeout_counter >= 100) begin
            $error("Timeout waiting for memory read_ready");
            return;
        end
        
        // Issue read request
        force dut.mem_address = address;
        force dut.mem_re = 1'b1;
        force dut.mem_we = 1'b0;
        force dut.mem_be = 1'b0;
        
        // Wait one cycle for request to register
        @(posedge clk);
        
        // Release control signals
        release dut.mem_address;
        release dut.mem_re;
        release dut.mem_we;
        release dut.mem_be;
        
        // Wait for read_valid signal
        timeout_counter = 0;
        while (!dut.mem_inst.read_valid && timeout_counter < 100) begin
            @(posedge clk);
            timeout_counter++;
        end
        
        if (timeout_counter >= 100) begin
            $error("Timeout waiting for memory read_valid");
            return;
        end
        
        // Capture the data when valid
        data = dut.mem_read_data;
        
        $display("[%0t] Reading from address 0x%08x: 0x%08x (latency: %0d cycles)", 
                $time, address, data, timeout_counter);
    endtask

    /**
     * Write memory word (writes have no latency)
     */
    task write_memory_word(input logic [31:0] address, input logic [31:0] data);
        automatic int timeout_counter = 0;
        
        // Wait for memory to be ready for writes
        while (!dut.mem_inst.write_ready && timeout_counter < 100) begin
            @(posedge clk);
            timeout_counter++;
        end
        
        if (timeout_counter >= 100) begin
            $error("Timeout waiting for memory write_ready");
            return;
        end
        
        // Issue write request
        force dut.mem_address = address;
        force dut.mem_write_data = data;
        force dut.mem_we = 1'b1;
        force dut.mem_re = 1'b0;
        force dut.mem_be = 1'b0;
        
        // Wait for write to complete
        @(posedge clk);
        
        // Release the forced signals
        release dut.mem_address;
        release dut.mem_write_data;
        release dut.mem_we;
        release dut.mem_re;
        release dut.mem_be;
        
        $display("[%0t] Writing to address 0x%08x: 0x%08x", $time, address, data);
    endtask

    /**
     * Verify memory initialization with latency handling
     */
    task verify_memory_initialization();
        logic [31:0] read_data;
        
        $display("\n=== VERIFYING MEMORY INITIALIZATION (with latency) ===");
        
        // Check weight dimensions
        read_memory_word(WEIGHTS_ADDR, read_data);
        $display("Weight width: %0d", read_data);
        
        read_memory_word(WEIGHTS_ADDR + 4, read_data);
        $display("Weight height: %0d", read_data);
        
        // Check some weight values
        for (int i = 0; i < 4; i++) begin
            read_memory_word(WEIGHTS_ADDR + 8 + i*4, read_data);
            $display("Weight row %0d: 0x%08x", i, read_data);
        end
        
        // Check input image dimensions
        read_memory_word(INPUT_ADDR, read_data);
        $display("Input width: %0d", read_data);
        
        read_memory_word(INPUT_ADDR + 4, read_data);
        $display("Input height: %0d", read_data);
        
        // Check some input data
        for (int i = 0; i < 4; i++) begin
            read_memory_word(INPUT_ADDR + 8 + i*4, read_data);
            $display("Input data %0d: 0x%08x", i, read_data);
        end
        
        $display("=== MEMORY INITIALIZATION VERIFIED ===\n");
    endtask

    // =============================================
    // Debug Display Tasks (UPDATED)
    // =============================================
    
    task display_memory_status();
        $display("\nMEMORY STATUS:");
        $display("  reset_done=%b, read_ready=%b, write_ready=%b", 
                dut.mem_inst.reset_done, dut.mem_inst.read_ready, dut.mem_inst.write_ready);
        $display("  read_valid=%b, read_pending=%b", 
                dut.mem_inst.read_valid, dut.mem_inst.read_request_pending);
        $display("  read_count=%0d, write_count=%0d, bytes=%0d", 
                dut.mem_inst.read_counter, dut.mem_inst.write_counter, dut.mem_inst.bytes_counter);
        
        // Show read pipeline status
        $display("  read_pipe_valid=%b", dut.mem_inst.read_pipe_valid);
        for (int i = 0; i < 2; i++) begin  // Assuming READ_LATENCY=2
            $display("  read_pipe_addr[%0d]=0x%08x", i, dut.mem_inst.read_pipe_addr[i]);
        end
    endtask
    
    task display_sa_data;
        input string label;
        
        $display("\n========================================");
        $display("    %s", label);
        $display("========================================");
        
        // Display weight matrix
        $display("\nWEIGHT DATA:");
        for (int i = 0; i < BLOCK_SIZE; i++) begin
            $write("  Row %0d: ", i);
            for (int j = 0; j < BLOCK_SIZE; j++) begin
                $write("%4d ", $signed(dut.weight_data[i][j]));
            end
            $display("");
        end
        
        // Display input block
        $display("\nINPUT DATA:");
        for (int i = 0; i < BLOCK_SIZE; i++) begin
            $write("  Row %0d: ", i);
            for (int j = 0; j < BLOCK_SIZE; j++) begin
                $write("%4d ", $signed(dut.input_block[i][j]));
            end
            $display("");
        end
        
        // Display output results
        $display("\nOUTPUT DATA:");
        for (int i = 0; i < BLOCK_SIZE; i++) begin
            $write("  Row %0d: ", i);
            for (int j = 0; j < BLOCK_SIZE; j++) begin
                $write("%8d ", dut.sa_inst.output_data[i][j]);
            end
            $display("");
        end
        
        // Display systolic array status
        $display("\nSA STATUS:");
        $display("  enable=%b, load_weights=%b, done=%b", 
                dut.sa_enable, dut.sa_load_weights, dut.sa_inst.done);
        $display("  processing=%b, cycle_count=%0d", 
                dut.sa_inst.processing, dut.sa_inst.cycle_count);
        
        // Display memory status
        display_memory_status();
        
        $display("========================================\n");
    endtask

    task show_block_processing(input int block_row, input int block_col);
        automatic int total_blocks_x = (100 + 3) / 4;  // Ceiling division for 100x100 image
        automatic int total_blocks_y = (100 + 3) / 4;
        automatic int current_block_num = (block_row/4) * total_blocks_x + (block_col/4) + 1;
        automatic int total_blocks = total_blocks_x * total_blocks_y;
        
        $display("\nPROCESSING BLOCK (%0d, %0d) - Block %0d/%0d", 
                 block_row, block_col, current_block_num, total_blocks);
        $display("   Block position in image: row %0d, col %0d", block_row, block_col);
        $display("   Image size: %0d x %0d", debug_width, debug_height);
        $display("   Progress: %0.1f%%", (real'(current_block_num) / real'(total_blocks)) * 100.0);
        display_memory_status();
    endtask
	 
	 task write_performance_report();
		  automatic integer file;
		  automatic real arithmetic_intensity;
		  
		  // Calculate arithmetic intensity
		  if (dut.total_bytes_transferred > 0) begin
			  arithmetic_intensity = real'(dut.total_mac_operations) / real'(dut.total_bytes_transferred);
		  end else begin
			  arithmetic_intensity = 0.0;
		  end
		  
		  file = $fopen("../../performance_report.txt", "w");
		  
		  $fdisplay(file, "=== PERFORMANCE REPORT (with RAM IP Latency) ===");
		  $fdisplay(file, "Total MAC operations: %0d", dut.total_mac_operations);
		  $fdisplay(file, "Total processing cycles: %0d", dut.total_processing_cycles);
		  $fdisplay(file, "Total memory accesses: %0d", dut.total_mem_accesses);
		  $fdisplay(file, "Total bytes transferred: %0d", dut.total_bytes_transferred);
		  $fdisplay(file, "Arithmetic intensity (Ai): %0.4f", arithmetic_intensity);
		  $fdisplay(file, "Memory efficiency: %0.2f%%", 
		           real'(dut.total_bytes_transferred) / real'(MEM_SIZE * 4) * 100.0);
		  $fdisplay(file, "Memory read latency: %0d cycles", 2);  // READ_LATENCY parameter
		  $fdisplay(file, "==========================");
		  
		  $fclose(file);
		  
		  // Show summary in console
		  $display("\n=== PERFORMANCE SUMMARY ===");
		  $display("Total MAC operations: %0d", dut.total_mac_operations);
		  $display("Total processing cycles: %0d", dut.total_processing_cycles);
		  $display("Total memory accesses: %0d", dut.total_mem_accesses);
		  $display("Total bytes transferred: %0d", dut.total_bytes_transferred);
		  $display("Arithmetic intensity (Ai): %0.4f", arithmetic_intensity);
		  $display("Memory efficiency: %0.2f%%", 
		           real'(dut.total_bytes_transferred) / real'(MEM_SIZE * 4) * 100.0);
		  $display("==========================");
    endtask

    /**
     * Write output data to file using memory interface with latency
     */
    task write_output_file();
        logic [31:0] read_data;
        
        file_handle = $fopen("../../data_out.hex", "w");
        
        $display("\nWriting output data to file (handling latency)...");
        
        // Write output image dimensions first
        read_memory_word(OUTPUT_ADDR, read_data);
        $fdisplay(file_handle, "%08h", read_data);
        
        read_memory_word(OUTPUT_ADDR + 4, read_data);
        $fdisplay(file_handle, "%08h", read_data);
        
        // Write output image data
        for (int i = 2; i < 1024; i++) begin  // Start from offset 8 (2 words)
            read_memory_word(OUTPUT_ADDR + i*4, read_data);
            $fdisplay(file_handle, "%08h", read_data);
            
            // Stop if we read too much (adjust based on your expected output size)
            if (i > 100 && read_data == 32'h00000000) break;
        end
        
        $fclose(file_handle);
        $display("Output data written to ../../data_out.hex");
    endtask

    // =============================================
    // Main Test Sequence (UPDATED for Latency)
    // =============================================
    initial begin
        $display("\nSTARTING IMAGE PROCESSOR TESTBENCH (RAM IP with Latency Handling)");
        $display("===================================================================");
        
        // Initialize signals
        reset = 1;
        start = 0;
        
        // Reset sequence - wait longer for IP RAM initialization
        repeat(20) @(posedge clk);
        reset = 0;
        
        // Wait for memory wrapper to be ready (longer timeout due to latency)
        wait(dut.mem_inst.reset_done);
        repeat(10) @(posedge clk);
        
        $display("Memory wrapper ready, verifying initialization...");
        
        // Verify memory initialization (this will test latency handling)
        verify_memory_initialization();
        
        // Start processing
        start = 1;
        @(posedge clk);
        start = 0;
        
        $display("Processing started...\n");
        
        // Parallel monitoring processes
        fork
            // Main completion monitor
            begin
                wait(done);
                $display("PROCESSING COMPLETED!");
                
                // Wait a few cycles for any pending memory operations to complete
                repeat(10) @(posedge clk);
                
                // Write output to file using memory interface
                write_output_file();
                
                // Write performance report
                write_performance_report();
                
                $display("\n=== Test completed successfully! ===\n");
                $finish;  // Terminate immediately after completion
            end
            
            // Block processing monitor
            begin
                automatic logic [3:0] prev_state = 4'hF;
                automatic logic [7:0] prev_block_row = 255;
                automatic logic [7:0] prev_block_col = 255;
                automatic int block_count = 0;
                
                while (!done) begin
                    @(posedge clk);
                    
                    // Detect new block processing
                    if (debug_state == 4'd9 && prev_state != 4'd9) begin  // PROCESS_BLOCK
                        block_count++;
                        show_block_processing(debug_block_row, debug_block_col);
                        display_sa_data($sformatf("BLOCK %0d PROCESSING", block_count));
                    end
                    
                    // Show results when processing is done
                    if (debug_state == 4'd11 && prev_state == 4'd10) begin  // WRITE_OUTPUT_BLOCK after WAIT_PROCESSING
                        display_sa_data($sformatf("BLOCK %0d RESULTS", block_count));
                    end
                    
                    prev_state = debug_state;
                end
            end
            
            // Memory access monitor with latency awareness
            begin
                automatic int prev_mem_accesses = 0;
                while (!done) begin
                    @(posedge clk);
                    if (total_mem_accesses != prev_mem_accesses) begin
                        if (total_mem_accesses % 50 == 0) begin  // Print every 50 accesses
                            $display("[%0t] Memory accesses: %0d, Bytes: %0d, Read_valid: %b", 
                                   $time, total_mem_accesses, total_bytes_transferred, dut.mem_inst.read_valid);
                        end
                        prev_mem_accesses = total_mem_accesses;
                    end
                end
            end
        join
        
        // This code should not be reached due to $finish in completion monitor
    end

    // =============================================
    // Infinite Loop Detection (NEW)
    // =============================================
    initial begin
        automatic logic [3:0] prev_state = 4'hF;
        automatic int state_cycle_count = 0;
        automatic int same_addr_write_count = 0;
        automatic logic [31:0] prev_write_addr = 32'hFFFFFFFF;
        
        forever begin
            @(posedge clk);
            
            // Detect if we're stuck in the same state too long
            if (debug_state == prev_state) begin
                state_cycle_count++;
                // Don't flag DONE_STATE as infinite loop - it's a terminal state
                if (state_cycle_count > 1000 && debug_state != 4'd14) begin  // 4'd14 = DONE_STATE
                    $error("INFINITE LOOP DETECTED: Stuck in state %s for %0d cycles", 
                           get_state_name(debug_state), state_cycle_count);
                    $display("Current signals: mem_op_count=%0d, mem_we=%b, mem_re=%b", 
                            dut.mem_op_count, dut.mem_we, dut.mem_re);
                    $display("Memory status: ready=%b, valid=%b", 
                            dut.mem_inst.write_ready, dut.mem_inst.read_valid);
                    $finish;
                end
            end else begin
                state_cycle_count = 0;
                prev_state = debug_state;
            end
            
            // Detect repeated writes to same address
            if (dut.mem_we) begin
                if (dut.mem_address == prev_write_addr) begin
                    same_addr_write_count++;
                    if (same_addr_write_count > 100) begin  // Same address 100+ times
                        $error("INFINITE WRITE LOOP: Writing to address 0x%08x %0d times", 
                               dut.mem_address, same_addr_write_count);
                        $finish;
                    end
                end else begin
                    same_addr_write_count = 0;
                    prev_write_addr = dut.mem_address;
                end
            end
        end
    end
    initial begin
        #50000000; // 500ms timeout (should not be needed with auto-termination)
        if (!done) begin
            $error("TIMEOUT: Processing took longer than expected (>500ms)");
            $display("Last state: %s", get_state_name(debug_state));
            $display("Memory wrapper ready: %b", dut.mem_inst.reset_done);
            display_memory_status();
            if (debug_state == 4'd10) begin  // WAIT_PROCESSING
                display_sa_data("TIMEOUT DEBUG INFO");
            end
            $finish;
        end else begin
            $display("WARNING: Timeout reached but processing already completed - test should have auto-terminated");
        end
    end

    // =============================================
    // State Change Monitor (UPDATED)
    // =============================================
    initial begin
        automatic logic [3:0] last_state = 4'hF;
        
        forever begin
            @(posedge clk);
            if (debug_state != last_state) begin
                $display("[%0t] State: %s", $time, get_state_name(debug_state));
                last_state = debug_state;
                
                // Show memory status on state changes related to memory operations
                if (debug_state == 4'd1 || debug_state == 4'd2 || debug_state == 4'd3 || 
                    debug_state == 4'd4 || debug_state == 4'd5 || debug_state == 4'd6 || 
                    debug_state == 4'd7 || debug_state == 4'd8) begin
                    display_memory_status();
                end
                
                // Show processing completion status
                if (debug_state == 4'd12) begin  // NEXT_BLOCK
                    $display("   Processing complete flag: %b", processing_complete);
                    $display("   Current block: (%0d, %0d)", debug_block_row, debug_block_col);
                end
            end
        end
    end

    // =============================================
    // Memory Pipeline Monitor (New for Latency Debug)
    // =============================================
    initial begin
        forever begin
            @(posedge clk);
            
            // Monitor read pipeline
            if (dut.mem_inst.read_pipe_valid != 0 || dut.mem_re || dut.mem_inst.read_valid) begin
                $display("[%0t] MEM_PIPELINE: re=%b, pipe_valid=%b, read_valid=%b, addr=0x%08x, data=0x%08x", 
                       $time, dut.mem_re, dut.mem_inst.read_pipe_valid, 
                       dut.mem_inst.read_valid, dut.mem_address, dut.mem_read_data);
            end
            
            // Monitor write operations
            if (dut.mem_we) begin
                $display("[%0t] MEM_WRITE: addr=0x%08x, data=0x%08x, ready=%b", 
                       $time, dut.mem_address, dut.mem_write_data, dut.mem_inst.write_ready);
            end
        end
    end

endmodule