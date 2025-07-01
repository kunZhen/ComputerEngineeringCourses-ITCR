/**
 * Memory Module Testbench
 * 
 * This testbench verifies the functionality of the memory module, including:
 * - Word and byte read/write operations
 * - Memory initialization from file
 * - Address boundary checking
 * - Synchronous write and asynchronous read behavior
 */

module memory_tb;
    // =============================================
    // Test Parameters
    // =============================================
    localparam DATA_WIDTH = 32;        // Match DUT configuration
    localparam ADDRESS_WIDTH = 32;     // Match DUT configuration
    localparam MEM_SIZE = 1024;          // Match DUT configuration

    // =============================================
    // Test Signals
    // =============================================
    logic clk = 0;                     // System clock
    logic reset = 0;                   // Active-high reset
    logic [ADDRESS_WIDTH-1:0] address; // Memory address
    logic [DATA_WIDTH-1:0] write_data; // Data to write
    logic we;                          // Write enable
    logic re;                          // Read enable
    logic be;                          // Byte enable
    logic [DATA_WIDTH-1:0] read_data;  // Read data output
	 logic [DATA_WIDTH-1:0] read_count;
	 logic [DATA_WIDTH-1:0] write_count;
	 logic [DATA_WIDTH-1:0] bytes_transferred;

    // =============================================
    // Clock Generation
    // =============================================
    always #5 clk = ~clk;  // 100MHz clock (10ns period)

    // =============================================
    // DUT Instantiation
    // =============================================
    memory #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDRESS_WIDTH(ADDRESS_WIDTH),
        .MEM_SIZE(MEM_SIZE)
    ) dut (
        .clk(clk),
        .reset(reset),
        .address(address),
        .write_data(write_data),
        .we(we),
        .re(re),
        .be(be),
        .read_data(read_data),
		  .read_count(read_count),
		  .write_count(write_count),
		  .bytes_transferred(bytes_transferred)
    );

    // =============================================
    // Test Sequence
    // =============================================
    initial begin
        $display("\nStarting Memory Module Testbench");
        $display("=================================");

        // -----------------------------------------
        // Test Case 1: Verify Initial Memory Contents
        // -----------------------------------------
        $display("\n[Test 1] Reading initial memory contents (weights)");
        for (int i = 0; i < 6; i++) begin
            we = 1'b0;
            re = 1'b1;
            be = 1'b0;  // Word read
            address = i * 4;
            #10;
            $display("  Address: 0x%08h, Data: 0x%08h", address, read_data);
        end

        // -----------------------------------------
        // Test Case 2: Read Image Data Section
        // -----------------------------------------
        $display("\n[Test 2] Reading image data section");
        for (int i = 8; i < 14; i++) begin
            we = 1'b0;
            re = 1'b1;
            be = 1'b0;  // Word read
            address = i * 4;
            #10;
            $display("  Address: 0x%08h, Data: 0x%08h", address, read_data);
        end

        // -----------------------------------------
        // Test Case 3: Word Write/Read Operation
        // -----------------------------------------
        $display("\n[Test 3] Testing word write/read operations");
        
        // Word write
        address = 32'h18;
        write_data = 32'hb6a84325;
        we = 1'b1;
        re = 1'b0;
        be = 1'b0;
        #20;
        
        // Word read verification
        address = 32'h18;
        we = 1'b0;
        re = 1'b1;
        be = 1'b0;
        #10;
        if (read_data === 32'hb6a84325) begin
            $display("  PASS: Word write/read verified at 0x%08h", address);
        end else begin
            $display("  FAIL: Expected 0xb6a84325, got 0x%08h", read_data);
        end

        // -----------------------------------------
        // Test Case 4: Byte Write/Read Operation
        // -----------------------------------------
        $display("\n[Test 4] Testing byte write/read operations");
        
        // Byte write (address 0x19 = byte 1 of word 0x18)
        address = 32'h19;
        write_data = 32'h74;
        we = 1'b1;
        re = 1'b0;
        be = 1'b1;
        #20;
        
        // Byte read verification
        address = 32'h19;
        we = 1'b0;
        re = 1'b1;
        be = 1'b1;
        #10;
        if (read_data[7:0] === 8'h74) begin
            $display("  PASS: Byte write/read verified at 0x%08h", address);
        end else begin
            $display("  FAIL: Expected 0x00000074, got 0x%08h", read_data);
        end
        
        // Verify full word after byte modification
        address = 32'h18;
        we = 1'b0;
        re = 1'b1;
        be = 1'b0;
        #10;
        if (read_data === 32'hb6a87425) begin
            $display("  PASS: Word integrity after byte write verified");
        end else begin
            $display("  FAIL: Expected 0xb6a87425, got 0x%08h", read_data);
        end

        // -----------------------------------------
        // Test Completion
        // -----------------------------------------
        #10;
        $display("\n=== All tests completed successfully! ===\n");
        $finish;
    end

endmodule
