#ifndef MAIN_MEMORY_HPP
#define MAIN_MEMORY_HPP

#include <vector>
#include <cstdint>
#include <string>
#include <stdexcept>

class MainMemory {
private:
    std::vector<uint32_t> memory;  // Memory as 32-bit words
    const uint32_t MEM_SIZE_WORDS = 16 * 1024 * 1024;  // 64 MB / 4 = 16M words

    /**
     * @brief Checks if address is aligned and within bounds
     * @param addr Memory address to check
     * @throws std::runtime_error for unaligned access
     * @throws std::out_of_range for out of bounds access
     */
    void checkAlignment(uint32_t addr) const;

public:
    /**
     * @brief Constructor initializes memory with zeros
     */
    MainMemory();

    /**
     * @brief Writes a 32-bit word to memory
     * @param addr Word-aligned memory address
     * @param data 32-bit data to write
     */
    void writeWord(uint32_t addr, uint32_t data);

    /**
     * @brief Reads a 32-bit word from memory
     * @param addr Word-aligned memory address
     * @return The 32-bit word read
     */
    uint32_t readWord(uint32_t addr) const;

    /**
     * @brief Writes a single byte to memory
     * @param addr Byte address (doesn't need alignment)
     * @param data 8-bit data to write
     */
    void writeByte(uint32_t addr, uint8_t data);

    /**
     * @brief Reads a single byte from memory
     * @param addr Byte address (doesn't need alignment)
     * @return The 8-bit byte read
     */
    uint8_t readByte(uint32_t addr) const;

    /**
     * @brief Loads image data from file into memory
     * @param filename Image file in hex format
     * @param base_addr Starting memory address (must be word-aligned)
     */

    /**
     * @brief Loads data from file
     * @param filename Path to input file
     * @throws std::runtime_error for file errors or invalid format
     */
    void loadFromFile(const std::string& filename, uint32_t base_addr);

    /**
     * @brief Saves image data from memory to file
     * @param filename Output image file
     * @param base_addr Starting memory address containing image data
     */
    void saveImage(const std::string& filename, uint32_t base_addr);
};

#endif // MAIN_MEMORY_HPP