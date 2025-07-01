#include <iomanip>
#include <algorithm>
#include "image_processor.hpp"

ImageProcessor::ImageProcessor(MainMemory& mem) : memory(mem), width(0), height(0) {}

int16_t ImageProcessor::convertTo16BitSigned(uint8_t pixel) const {
    return static_cast<int16_t>(pixel) - 128;
}

uint8_t ImageProcessor::convertTo8BitUnsigned(int32_t value) const {
    return static_cast<uint8_t>(value);
}

void ImageProcessor::getImageSize(uint32_t base_addr) {
    width = memory.readWord(base_addr);
    height = memory.readWord(base_addr + 4);
}

void ImageProcessor::processImage(SystolicArray& systolic, uint32_t input_addr, uint32_t output_addr) {
    getImageSize(input_addr);
    uint32_t block_size = systolic.getSize();

    // Skip the width and height of the input image stored in main memory
    input_addr += 8;

    // Save output image size
    memory.writeWord(output_addr, width);
    memory.writeWord(output_addr + 4, height);

    // Skip the width and height of the output image stored in main memory
    output_addr += 8;

    // Process image in nxn blocks
    for (uint32_t i = 0; i < height; i += block_size) {
        for (uint32_t j = 0; j < width; j += block_size) {
            uint32_t current_block_height = std::min(block_size, height - i);
            uint32_t current_block_width = std::min(block_size, width - j);

            // Get and process block
            auto input_block = getImageBlock(input_addr, i, j, current_block_height, current_block_width);
            auto output_block = systolic.processBlock(input_block);
            
            // Save output_block to main memory
            for (uint16_t bi = 0; bi < current_block_height; ++bi) {
                for (uint16_t bj = 0; bj < current_block_width; bj += 4) {
                    uint32_t word = 0;
                    
                    for (uint8_t k = 0; k < 4; ++k) {
                        if (bj + k < current_block_width) {
                            uint8_t pixel8 = convertTo8BitUnsigned(output_block[bi][bj + k]);
                            word |= (pixel8 << (8 * k));
                        }
                    }
                    uint32_t addr = output_addr + ((i + bi) * width + (j + bj));
                    memory.writeWord(addr, word);
                }
            }
        }
    }
}

std::vector<std::vector<int16_t>> ImageProcessor::getImageBlock(
    uint32_t base_addr,
    uint16_t start_row, 
    uint16_t start_col,
    uint16_t block_height, 
    uint16_t block_width
) const {
    if (start_row + block_height > height || start_col + block_width > width) {
        throw std::out_of_range("Requested block exceeds image dimensions");
    }

    std::vector<std::vector<int16_t>> block(block_height, std::vector<int16_t>(block_width));

    for (uint16_t i = 0; i < block_height; ++i) {
        for (uint16_t j = 0; j < block_width; ++j) {
            uint32_t pixel_index = (start_row + i) * width + (start_col + j);
            uint32_t byte_addr = base_addr + pixel_index;

            uint32_t word_addr = byte_addr & ~0x3;  // 4-byte aligned address
            uint32_t word = memory.readWord(word_addr);

            // Extract the correct 8-bit pixel and cast to int16_t
            uint8_t pixel_byte;
            uint8_t byte_offset = byte_addr % 4;

            switch (byte_offset) {
                case 0:
                    pixel_byte = static_cast<uint8_t>(word & 0xFF);         // byte 0 (least significant)
                    break;
                case 1:
                    pixel_byte = static_cast<uint8_t>((word >> 8) & 0xFF);  // byte 1
                    break;
                case 2:
                    pixel_byte = static_cast<uint8_t>((word >> 16) & 0xFF); // byte 2
                    break;
                case 3:
                    pixel_byte = static_cast<uint8_t>((word >> 24) & 0xFF); // byte 3 (most significant)
                    break;
                default:
                    pixel_byte = 0; 
            }

            block[i][j] = convertTo16BitSigned(pixel_byte);
        }
    }

    return block;
}
