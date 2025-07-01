#ifndef CACHE_MEMORY_HPP
#define CACHE_MEMORY_HPP

#include <vector>
#include <cstdint>
#include <fstream>
#include <random>
#include <iostream>
#include <iomanip>
#include "constants.hpp"

/**
 * @brief Structure representing a block of memory in the cache.
 * 
 * Contains data and a validity flag.
 */
struct MemoryBlock {
    std::vector<uint32_t> data;     // 4 words of 32 bits (16 bytes total)
    bool valid;                     // Validity bit
    
    /**
     * @brief Constructor initializing the block with 4 words set to zero.
     */
    MemoryBlock() : data(4, 0), valid(true) {}
};

/**
 * @brief Class representing cache memory with block-level operations.
 * 
 * Provides methods for reading and writing blocks or individual words within blocks,
 * as well as loading and saving cache contents from/to files.
 */
class CacheMemory {
private:
    std::vector<MemoryBlock> memory;
    
public:
    /**
     * @brief Constructor initializing cache memory with NUMBER_OF_CACHE_BLOCKS blocks.
     * 
     * Each block is initialized by the MemoryBlock constructor.
     */
    CacheMemory() : memory(NUMBER_OF_CACHE_BLOCKS) {}

    /**
     * @brief Writes a complete block (4 words of 32 bits) to the cache.
     * 
     * @param block_index Index of the block to write
     * @param words Vector of 4 words to write into the block
     * 
     * @throws std::out_of_range if block index is out of range
     * @throws std::invalid_argument if the number of words is not exactly 4
     */
    void writeBlock(uint8_t block_index, const std::vector<uint32_t>& words);

    /**
     * @brief Writes a specific word within a block.
     * 
     * @param block_index Index of the block
     * @param word_offset Offset of the word within the block
     * @param value 32-bit value to write
     * 
     * @throws std::out_of_range if block index or word offset is out of range
     */
    void writeWord(uint8_t block_index, uint8_t word_offset, uint32_t value);

    /**
     * @brief Reads a complete block (4 words of 32 bits) from the cache.
     * 
     * @param block_index Index of the block to read
     * @return Reference to the vector of words in the block
     * 
     * @throws std::out_of_range if block index is out of range
     * @throws std::runtime_error if attempting to read an invalid block
     */
    const std::vector<uint32_t>& readBlock(uint8_t block_index) const;

    /**
     * @brief Reads a specific word from a block.
     * 
     * @param block_index Index of the block
     * @param word_offset Offset of the word within the block
     * @return 32-bit value of the word
     * 
     * @throws std::out_of_range if block index or word offset is out of range
     * @throws std::runtime_error if attempting to read an invalid block
     */
    uint32_t readWord(uint8_t block_index, uint8_t word_offset) const;

    /**
     * @brief Invalidates a specific block.
     * 
     * @param block_index Index of the block to invalidate
     * 
     * @throws std::out_of_range if block index is out of range
     */
    void invalidateBlock(uint8_t block_index);

    /**
     * @brief Validates a specific block.
     * 
     * @param block_index Index of the block to validate
     * 
     * @throws std::out_of_range if block index is out of range
     */
    void validateBlock(uint8_t block_index);

    /**
     * @brief Checks if a block is valid.
     * 
     * @param block_index Index of the block to check
     * @return True if the block is valid, false otherwise
     * 
     * @throws std::out_of_range if block index is out of range
     */
    bool isBlockValid(uint8_t block_index) const;

    /**
     * @brief Fills the entire cache with random values.
     * 
     * Optionally takes a seed for the random number generator.
     * 
     * @param seed Seed for random number generator (default: random device)
     */
    void fillRandom(uint32_t seed = std::random_device{}());

    /**
     * @brief Loads cache contents from a file.
     * 
     * @param filename Path to file containing hexadecimal data
     * @return True if load was successful, false otherwise
     */
    bool loadFromFile(const std::string& filename);

    /**
     * @brief Saves cache contents to a file.
     * 
     * @param filename Path to output file
     * @return True if save was successful, false otherwise
     */
    bool saveToFile(const std::string& filename);

    /**
     * @brief Prints information about the cache memory.
     */
    void showInfo() const;
};

#endif // CACHE_MEMORY_HPP
