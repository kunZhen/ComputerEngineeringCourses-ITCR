#include <fstream>
#include <iomanip>
#include <algorithm>
#include "systolic_array.hpp"

SystolicArray::SystolicArray(uint16_t size, MainMemory& mem, uint32_t weights_addr) 
    : size(size), memory(mem) {
    // Initialize processing elements with weights
    pes.resize(size, std::vector<ProcessingElement>(size));

    loadWeights(weights_addr);

    // Print values ​​to verify
    std::cout << "\nWeights content:" << std::endl;
    for (const auto& row : weights) {
        for (auto val : row) {
            std::cout << std::dec << val << "\t";
        }
        std::cout << std::endl;
    }

    // Create and assign weight to each PE
    for (uint16_t i = 0; i < size; ++i) {
        for (uint16_t j = 0; j < size; ++j) {
            pes[i][j] = ProcessingElement(weights[i][j]);
        }
    }
}

void SystolicArray::loadWeights(uint32_t weights_addr) {
    weights.resize(size, std::vector<int16_t>(size));

    // Skip the width and height of the weight array stored in main memory
    weights_addr += 0x8;

    for (uint16_t i = 0; i < size; ++i) {
        for (uint16_t j = 0; j < size; ++j) {
            uint32_t addr = weights_addr + i * size + (size - 1 - j);
            uint8_t byte_val = memory.readByte(addr);
            weights[i][j] = static_cast<int16_t>(static_cast<int8_t>(byte_val));
        }
    }
}

std::vector<std::vector<int32_t>> SystolicArray::processBlock(
    const std::vector<std::vector<int16_t>>& input_block
) {
    // [LOG] Initialize processing log
    std::ofstream logfile("../resources/files/logs.txt", std::ios::app);
    logfile << "\n=== Starting processBlock() ===\n";

    std::vector<std::vector<int32_t>> output_block(size, std::vector<int32_t>(size, 0));

    logfile << "\nINPUT DATA:\n";
    for (const auto& row : input_block) {
        for (const auto& val : row) {
            logfile << std::setw(4) << val << " ";
        }
        logfile << "\n";
    }

    // Log the weights matrix
    logfile << "\nWEIGHT DATA:\n";
    for (uint16_t i = 0; i < size; ++i) {
        for (uint16_t j = 0; j < size; ++j) {
            logfile << std::setw(4) << pes[i][j].getWeight() << " ";
        }
        logfile << "\n";
    }

    // Reset all PEs
    for (auto& row : pes) {
        for (auto& pe : row) {
            pe.reset();
        }
    }

    // Simulate 2*size - 1 cycles (full pipeline)
    for (int t = 0; t < 2 * size - 1; ++t) {
        logfile << "\n--- CYCLE " << t << " ---\n";
        
        // Log input data injection for this cycle
        logfile << "Input data injection:\n";
        for (int row = 0; row < size; ++row) {
            int input_col = t - row;
            int16_t input_val = 0;
            if (input_col >= 0 && input_col < size && row < static_cast<int>(input_block.size()) && input_col < static_cast<int>(input_block[row].size())) {
                input_val = input_block[row][input_col];
                logfile << "  Row " << row << ": input_block[" << row << "][" << input_col << "] = " << input_val << "\n";
            } else {
                logfile << "  Row " << row << ": no input (padding with 0)\n";
            }
        }

        // Log partial sum propagation before processing
        logfile << "\nPartial sum propagation (bottom-up):\n";
        for (int row = 0; row < size; ++row) {
            for (int col = 0; col < size; ++col) {
                int32_t partial_in = 0;
                if (row < size - 1) {
                    partial_in = pes[row + 1][col].getResult();
                }
                logfile << "  PE[" << row << "][" << col << "]: partial_in = " << partial_in;
                if (row < size - 1) {
                    logfile << " (from PE[" << (row + 1) << "][" << col << "])";
                } else {
                    logfile << " (bottom row, no input)";
                }
                logfile << "\n";
            }
        }

        // Create a temporary array to store the new partial values
        std::vector<std::vector<int32_t>> new_partials(size, std::vector<int32_t>(size, 0));

        // Process each PE and log the computation
        logfile << "\nPE Computations:\n";
        for (int row = 0; row < size; ++row) {
            for (int col = 0; col < size; ++col) {
                // Get input value for this PE
                int input_col = t - row;
                int16_t input_val = 0;
                if (input_col >= 0 && input_col < size && row < static_cast<int>(input_block.size()) && input_col < static_cast<int>(input_block[row].size())) {
                    input_val = input_block[row][input_col];
                }

                // Get partial sum from below
                int32_t partial_in = 0;
                if (row < size - 1) {
                    partial_in = pes[row + 1][col].getResult();
                }

                // Get current weight
                int16_t weight = pes[row][col].getWeight();

                // Compute product
                int32_t product = static_cast<int32_t>(input_val) * weight;

                // Execute the PE
                new_partials[row][col] = pes[row][col].process(input_val, partial_in);

                // Log detailed computation
                logfile << "  PE[" << row << "][" << col << "]: "
                        << "input=" << input_val 
                        << " * weight=" << weight 
                        << " = " << product
                        << ", partial_in=" << partial_in
                        << " -> result=" << new_partials[row][col] << "\n";
            }
        }

        // Log the current state of all PEs after this cycle
        logfile << "\nPE States after cycle " << t << ":\n";
        for (int row = 0; row < size; ++row) {
            logfile << "  Row " << row << ": ";
            for (int col = 0; col < size; ++col) {
                logfile << std::setw(8) << pes[row][col].getResult() << " ";
            }
            logfile << "\n";
        }

        // Log data flow visualization
        logfile << "\nData Flow Visualization:\n";
        logfile << "┌─────┬─────┬─────┬─────┐\n";
        for (int row = 0; row < size; ++row) {
            logfile << "│";
            for (int col = 0; col < size; ++col) {
                logfile << std::setw(4) << pes[row][col].getResult() << " │";
            }
            logfile << "\n";
            if (row < size - 1) {
                logfile << "├─────┼─────┼─────┼─────┤\n";
            }
        }
        logfile << "└─────┴─────┴─────┴─────┘\n";

        // Log which PEs are actively computing (receiving valid input)
        logfile << "\nActive PEs (receiving valid input):\n";
        for (int row = 0; row < size; ++row) {
            int input_col = t - row;
            if (input_col >= 0 && input_col < size && row < static_cast<int>(input_block.size()) && input_col < static_cast<int>(input_block[row].size())) {
                logfile << "  PE[" << row << "][*] is active\n";
            }
        }
    }

    logfile << "\n=== FINAL RESULTS EXTRACTION ===\n";
    logfile << "Final PE states:\n";
    for (int row = 0; row < size; ++row) {
        logfile << "Row " << row << ": ";
        for (int col = 0; col < size; ++col) {
            logfile << std::setw(8) << pes[row][col].getResult() << " ";
        }
        logfile << "\n";
    }

    // Get the final results and apply post-processing
    logfile << "\nPost-processing (clamp to [-128,127] + 128 offset):\n";
    for (int row = 0; row < size; ++row) {
        for (int col = 0; col < size; ++col) {
            int32_t raw_result = pes[row][col].getResult();
            int32_t clamped = std::clamp(raw_result, -128, 127);
            output_block[row][col] = clamped + 128;
            
            logfile << "  PE[" << row << "][" << col << "]: " 
                    << raw_result << " -> clamp(" << clamped << ") -> final(" 
                    << output_block[row][col] << ")\n";
        }
    }

    logfile << "\nOUTPUT DATA:\n";
    for (const auto& row : output_block) {
        for (const auto& val : row) {
            logfile << std::setw(6) << val << " ";
        }
        logfile << "\n";
    }

    logfile << "\n=== processBlock() completed ===\n\n";
    logfile.close();

    return output_block;
}

uint16_t SystolicArray::getSize() const {
    return size;
}