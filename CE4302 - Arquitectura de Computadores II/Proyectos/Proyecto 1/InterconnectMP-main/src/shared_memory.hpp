#ifndef SHARED_MEMORY_HPP
#define SHARED_MEMORY_HPP

#include <vector>
#include <mutex>
#include <fstream>
#include <iostream>
#include <iomanip>
#include <random>
#include <stdexcept>
#include "constants.hpp"

/**
 * @brief Class representing a shared memory with thread-safe operations.
 * 
 * Provides methods for reading and writing 32-bit words to shared memory,
 * as well as loading and saving its contents from/to files.
 */
class SharedMemory {
private:
    std::vector<uint32_t> memory;   // Stores 32-bit words (4 bytes)
    std::mutex mem_mutex;           // Mutex to ensure thread-safe access
    
public:
    /**
     * @brief Constructor initializing shared memory with zeros.
     * 
     * Allocates memory of size SHARED_MEMORY_SIZE and initializes all words to zero.
     */
    SharedMemory() : memory(SHARED_MEMORY_SIZE, 0) {}

    /**
     * @brief Writes a 32-bit value to a memory address aligned to 4 bytes.
     * 
     * @param addr Memory address (must be a multiple of 4)
     * @param value 32-bit value to write
     * 
     * @throws std::runtime_error if address is not aligned to 4 bytes
     * @throws std::out_of_range if position is out of bounds
     */
    void writeByAddress(uint16_t addr, uint32_t value);

    /**
     * @brief Writes a 32-bit value to a specified memory position.
     * 
     * @param pos Memory position
     * @param value 32-bit value to write
     * 
     * @throws std::out_of_range if position is out of bounds
     */
    void writeByPosition(uint16_t pos, uint32_t value);

    /**
     * @brief Reads a 32-bit value from a memory address aligned to 4 bytes.
     * 
     * @param addr Memory address (must be a multiple of 4)
     * @return 32-bit value read from memory
     * 
     * @throws std::runtime_error if address is not aligned to 4 bytes
     * @throws std::out_of_range if position is out of bounds
     */
    uint32_t readByAddress(uint16_t addr);

    /**
     * @brief Reads a 32-bit value from a specified memory position.
     * 
     * @param pos Memory position
     * @return 32-bit value read from memory
     * 
     * @throws std::out_of_range if position is out of bounds
     */
    uint32_t readByPosition(uint16_t pos);

    /**
     * @brief Fills shared memory with random 32-bit values.
     * 
     * Optionally takes a seed for the random number generator.
     * 
     * @param seed Seed for random number generator (default: random device)
     */
    void fillRandom(uint32_t seed = std::random_device{}());

    /**
     * @brief Loads shared memory contents from a file in hexadecimal format.
     * 
     * @param filename Path to file containing hexadecimal data
     * @return True if load was successful, false otherwise
     */
    bool loadFromFile(const std::string& filename);

    /**
     * @brief Saves shared memory contents to a file in hexadecimal format.
     * 
     * @param filename Path to output file
     * @return True if save was successful, false otherwise
     */
    bool saveToFile(const std::string& filename);

    /**
     * @brief Prints information about the shared memory.
     */
    void showInfo() const;
};

#endif // SHARED_MEMORY_HPP
