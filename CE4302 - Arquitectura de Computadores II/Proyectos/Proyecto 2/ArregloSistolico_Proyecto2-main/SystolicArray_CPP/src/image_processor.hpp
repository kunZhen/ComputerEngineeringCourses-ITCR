#ifndef IMAGE_PROCESSOR_HPP
#define IMAGE_PROCESSOR_HPP

#include <vector>
#include <string>
#include <fstream>
#include <cstdint>
#include <iostream>
#include <algorithm>
#include "systolic_array.hpp"
#include "main_memory.hpp"

/**
 * @class ImageProcessor
 * @brief Class for processing images using a systolic array and main memory.
 * 
 * This class provides functionalities to load images from main memory,
 * divide them into blocks, process them using a systolic array, and save the results.
 */
class ImageProcessor {
private:
    MainMemory& memory; // Reference to main memory for reading/writing data
    uint16_t width;     // Image width 
    uint16_t height;    // Image height 

    /**
     * @brief Converts an 8-bit unsigned pixel to a 16-bit signed pixel
     * @param pixel 8-bit unsigned pixel value
     * @return 16-bit signed pixel value (centered around 0)
     */
    int16_t convertTo16BitSigned(uint8_t pixel) const;

    /**
     * @brief Converts a 32-bit signed value to an 8-bit unsigned pixel
     * @param value 32-bit signed value
     * @return 8-bit unsigned pixel value (in range 0-255)
     */
    uint8_t convertTo8BitUnsigned(int32_t value) const;

    /**
     * @brief Retrieves an image block from main memory
     * @param input_addr Base address of the image in memory
     * @param start_row Starting row of the block
     * @param start_col Starting column of the block
     * @param block_height Height of the block
     * @param block_width Width of the block
     * @return 2D matrix representing the image block in 16-bit signed format
     */
    std::vector<std::vector<int16_t>> getImageBlock(
        uint32_t input_addr,
        uint16_t start_row, 
        uint16_t start_col,
        uint16_t block_height, 
        uint16_t block_width
    ) const;

public:
    /**
     * @brief Constructor of ImageProcessor
     * @param mem Reference to main memory
     */
    explicit ImageProcessor(MainMemory& mem);

    /**
     * @brief Gets the image dimensions from main memory
     * @param base_addr Base address where the image width and height are stored
     */
    void getImageSize(uint32_t base_addr);

    /**
     * @brief Processes a complete image using the systolic array
     * @param systolic Reference to the systolic array for processing
     * @param input_addr Memory address of the input image
     * @param output_addr Memory address to store the processed image
     */
    void processImage(SystolicArray& systolic, uint32_t input_addr, uint32_t output_addr);
};

#endif // IMAGE_PROCESSOR_HPP
