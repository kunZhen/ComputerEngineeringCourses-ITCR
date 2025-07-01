// Memory
module memory #(
    parameter DATA_WIDTH = 32,        // Width of data bus (bits)
    parameter ADDRESS_WIDTH = 32,     // Width of address bus (bits)
    parameter MEM_SIZE = 8192           // Size of memory in words
) (
    // Clock and reset
    input logic clk,                  // System clock
    input logic reset,                // Active-high reset
    
    // Memory interface
    input logic [ADDRESS_WIDTH-1:0] address,   // Memory address
    input logic [DATA_WIDTH-1:0] write_data,   // Data to write
    input logic we,                            // Write enable
    input logic re,                            // Read enable
    input logic be,                            // Byte enable (1=byte, 0=word)
    
    // Data output
    output logic [DATA_WIDTH-1:0] read_data,   // Read data
	 
	 // Performance counters
    output logic [DATA_WIDTH-1:0] read_count,  // Reading counter
    output logic [DATA_WIDTH-1:0] write_count, // Writer counter
    output logic [DATA_WIDTH-1:0] bytes_transferred // Bytes transferred
);

    // =============================================
    // Memory Storage
    // =============================================
    logic [DATA_WIDTH-1:0] memory [0:MEM_SIZE-1];  // Memory array

    // =============================================
    // Memory Initialization
    // =============================================
    initial begin
        // Initialize memory from hex file
        $readmemh("data.hex", memory);
    end

    // =============================================
    // Write Operation (Synchronous)
    // =============================================
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
				read_count <= 0;
				write_count <= 0;
				bytes_transferred <= 0;
        end
        else begin
				if (we && (address < MEM_SIZE)) begin
					write_count <= write_count + 1;
					bytes_transferred <= bytes_transferred + (be ? 1 : 4);
					// Active write operation within memory bounds
					if (be) begin
						 // Byte write operation
						 case (address[1:0])
							  2'b00: memory[address[31:2]][7:0]   <= write_data[7:0];
							  2'b01: memory[address[31:2]][15:8]  <= write_data[7:0];
							  2'b10: memory[address[31:2]][23:16] <= write_data[7:0];
							  2'b11: memory[address[31:2]][31:24] <= write_data[7:0];
						 endcase
					end
					else begin
						 // Word write operation
						 memory[address[31:2]] <= write_data;
					end
				end
				
				if (re && (address < MEM_SIZE)) begin
					read_count <= read_count + 1;
               bytes_transferred <= bytes_transferred + (be ? 1 : 4);
				end
        end
    end
    
    // =============================================
    // Read Operation (Asynchronous)
    // =============================================
    always_comb begin
        // Default output
        read_data = '0;
        
        if (re && (address < MEM_SIZE)) begin
            if (be) begin
                // Byte read operation
                case (address[1:0])
                    2'b00: read_data = {24'b0, (memory[address[31:2]][7:0] === 8'hxx) ? 8'h00 : memory[address[31:2]][7:0]};
                    2'b01: read_data = {24'b0, (memory[address[31:2]][15:8] === 8'hxx) ? 8'h00 : memory[address[31:2]][15:8]};
                    2'b10: read_data = {24'b0, (memory[address[31:2]][23:16] === 8'hxx) ? 8'h00 : memory[address[31:2]][23:16]};
                    2'b11: read_data = {24'b0, (memory[address[31:2]][31:24] === 8'hxx) ? 8'h00 : memory[address[31:2]][31:24]};
                endcase
            end
            else begin
                // Word read operation
                if (memory[address[31:2]] === 32'hx) begin
                    // Handle uninitialized memory locations
                    read_data = 32'h0;
                end
                else begin
                    read_data = memory[address[31:2]];
                end
            end
        end
    end

endmodule
