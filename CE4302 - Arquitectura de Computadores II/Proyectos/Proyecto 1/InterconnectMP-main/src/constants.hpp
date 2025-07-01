#ifndef CONSTANTS_HPP
#define CONSTANTS_HPP

#include <cstdint>

const uint16_t SHARED_MEMORY_SIZE = 4096;       // 4096 32-bit positions
const uint8_t NUMBER_OF_CACHE_BLOCKS = 128;     // 128 blocks
const uint8_t WORDS_PER_BLOCK = 4;              // 4 32-bit words per block (16 bytes)

const uint8_t MIN_NUM_PES = 2;
const uint8_t MAX_NUM_PES = 16;
const uint8_t DEFAULT_NUM_PES = 8;

#endif // CONSTANTS_HPP