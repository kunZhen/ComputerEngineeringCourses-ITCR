#ifndef MESSAGE_HPP
#define MESSAGE_HPP

#include <vector>
#include <cstdint>

/**
 * @brief Message type used in communication between PEs, Interconnect and Shared Memory.
 */
enum class MessageType {
    WRITE_MEM, 
    READ_MEM, 
    BROADCAST_INVALIDATE, 
    INV_ACK, 
    INV_COMPLETE, 
    READ_RESP, 
    WRITE_RESP
};

/**
 * @brief Structure representing a message in the system.
 * 
 * Contains information about the message type, source and destination PE,
 * memory address, etc.
 */
struct Message {
    MessageType type;
    uint8_t src;                    // Source PE (e.g. 0x00-0x07)
    uint8_t dest;                   // Destination PE (for responses)
    uint16_t addr;                  // Shared memory address (multiples of 4)
    uint16_t size;                  // Number of 32-bit words to read from shared memory
    uint8_t cache_line;             // For BROADCAST_INVALIDATE
    uint8_t start_cache_line;       // First cache block
    uint8_t num_of_cache_lines;     // Number of cache blocks
    uint8_t qos;                    // PE priority (e.g. 0x00-0xFF)
    uint8_t status;                 // 0x1: OK or 0x0: NOT_OK
    std::vector<uint32_t> data = {};// 32-bit words. Data (for WRITE_MEM/READ_RESP)
};

#endif // MESSAGE_HPP
