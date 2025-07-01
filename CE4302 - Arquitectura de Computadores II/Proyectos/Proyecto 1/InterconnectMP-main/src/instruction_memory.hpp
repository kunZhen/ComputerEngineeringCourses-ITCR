#ifndef INSTRUCTION_MEMORY_HPP
#define INSTRUCTION_MEMORY_HPP

#include <iostream>
#include <fstream>
#include <queue>
#include <map>
#include <sstream>
#include <algorithm>
#include <iomanip>
#include "message.hpp"

/**
 * @brief Class to manage instruction memory, loading instructions from a file.
 *
 * Stores instructions in a queue for sequential processing.
 */
class InstructionMemory {
public:
    std::queue<Message> instructions; // Queue of instructions to be executed

    /**
     * @brief Loads instructions from a file into the instruction queue.
     *
     * Reads each line, parses it into an instruction, and adds it to the queue.
     * Supports WRITE_MEM, READ_MEM, and BROADCAST_INVALIDATE instructions.
     *
     * @param filename The name of the file to load instructions from.
     * @return true if the file was loaded successfully, false otherwise.
     */
    bool loadFromFile(const std::string& filename);

    /**
     * @brief Loads a vector of Message instructions into the instruction queue.
     * 
     * @param msgs Vector of Message structs to load into the queue.
     */
    void loadInstructions(const std::vector<Message>& msgs);

    /**
     * @brief Retrieves the next instruction from the queue.
     *
     * @return The next instruction in the queue.
     * @note This method removes the instruction from the queue.
     */
    Message nextInstruction();

    /**
     * @brief Checks if there are more instructions in the queue.
     *
     * @return true if there are more instructions, false otherwise.
     */
    bool hasInstructions() const;
};

#endif // INSTRUCTION_MEMORY_HPP
