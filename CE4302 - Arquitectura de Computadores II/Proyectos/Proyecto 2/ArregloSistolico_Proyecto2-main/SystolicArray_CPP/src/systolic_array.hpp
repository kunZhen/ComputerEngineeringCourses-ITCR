#ifndef SYSTOLIC_ARRAY_HPP
#define SYSTOLIC_ARRAY_HPP

#include <vector>
#include <string>
#include <iostream>
#include <algorithm>
#include "main_memory.hpp"
#include "processing_element.hpp"

/**
 * @class SystolicArray
 * @brief Implements a systolic array for matrix operations
 * 
 * This class represents a 2D systolic array of Processing Elements
 * that performs matrix multiplication operations with convolutional
 * kernel. Supports weight loading and pipelined processing.
 */
class SystolicArray {
private:
    uint16_t size;                                      // Dimension of the square array
    MainMemory& memory;                                 // Main system memory
    std::vector<std::vector<int16_t>> weights;          // 2D array of weights
    std::vector<std::vector<ProcessingElement>> pes;    // 2D array of Processing Elements

    /**
     * @brief Loads weights from main memory
     * @param weights_addr Memory address from which the system weights are stored
     */
    void loadWeights(uint32_t weights_addr);

public:
    /**
     * @brief Constructs a systolic array
     * @param size Size of the square array (default 4x4)
     * @param mem Main system memory
     * @param weights_addr Memory address from which the system weights are stored
     */
    SystolicArray(uint16_t size, MainMemory& mem, uint32_t weights_addr);

    /**
     * @brief Processes a block of input data through the systolic array
     * @param input_block 2D input data block (must match array size)
     * @return 2D result matrix after processing
     * @throws std::invalid_argument if input block size doesn't match array size
     */
    std::vector<std::vector<int32_t>> processBlock(const std::vector<std::vector<int16_t>>& input_block);

    /**
     * @brief Returns the size of the systolic array
     * @return Size of the systolic array
     */
    uint16_t getSize() const;
};

#endif // SYSTOLIC_ARRAY_HPP