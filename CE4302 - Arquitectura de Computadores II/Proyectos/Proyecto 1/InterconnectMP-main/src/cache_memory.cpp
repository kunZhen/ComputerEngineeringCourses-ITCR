#include <random>
#include <stdexcept>
#include "cache_memory.hpp"

void CacheMemory::writeBlock(uint8_t block_index, const std::vector<uint32_t>& words) {
    if (block_index >= NUMBER_OF_CACHE_BLOCKS) {
        throw std::out_of_range("Block index out of range");
    }
    if (words.size() != WORDS_PER_BLOCK) {
        throw std::invalid_argument("Exactly 4 words are required per block");
    }
    
    memory[block_index].data = words;
    memory[block_index].valid = true;
}

void CacheMemory::writeWord(uint8_t block_index, uint8_t word_offset, uint32_t value) {
    if (block_index >= NUMBER_OF_CACHE_BLOCKS) {
        throw std::out_of_range("Block index out of range");
    }
    if (word_offset >= WORDS_PER_BLOCK) {
        throw std::out_of_range("Word offset out of range");
    }
    
    memory[block_index].data[word_offset] = value;
    memory[block_index].valid = true;
}

const std::vector<uint32_t>& CacheMemory::readBlock(uint8_t block_index) const {
    if (block_index >= NUMBER_OF_CACHE_BLOCKS) {
        throw std::out_of_range("Block index out of range");
    }
    if (!memory[block_index].valid) {
        throw std::runtime_error("Attempt to read an invalid block");
    }
    
    return memory[block_index].data;
}

uint32_t CacheMemory::readWord(uint8_t block_index, uint8_t word_offset) const {
    if (block_index >= NUMBER_OF_CACHE_BLOCKS) {
        throw std::out_of_range("Block index out of range");
    }
    if (word_offset >= WORDS_PER_BLOCK) {
        throw std::out_of_range("Word offset out of range");
    }
    if (!memory[block_index].valid) {
        throw std::runtime_error("Attempt to read an invalid block");
    }
    
    return memory[block_index].data[word_offset];
}

void CacheMemory::invalidateBlock(uint8_t block_index) {
    if (block_index >= NUMBER_OF_CACHE_BLOCKS) {
        throw std::out_of_range("Block index out of range");
    }
    memory[block_index].valid = false;
}

void CacheMemory::validateBlock(uint8_t block_index) {
    if (block_index >= NUMBER_OF_CACHE_BLOCKS) {
        throw std::out_of_range("Block index out of range");
    }
    memory[block_index].valid = true;
}

bool CacheMemory::isBlockValid(uint8_t block_index) const {
    if (block_index >= NUMBER_OF_CACHE_BLOCKS) {
        throw std::out_of_range("Block index out of range");
    }
    return memory[block_index].valid;
}

void CacheMemory::fillRandom(uint32_t seed) {
    std::mt19937 gen(seed);
    std::uniform_int_distribution<uint32_t> dist;
    
    for (auto& block : memory) {
        block.data.resize(WORDS_PER_BLOCK);
        for (auto& word : block.data) {
            word = dist(gen);
        }
        block.valid = true;
    }
}

bool CacheMemory::loadFromFile(const std::string& filename) {
    try {
        std::ifstream file(filename);
        if (!file) {
            return false;
        }

        std::string line;
        uint8_t current_block = 0;
        uint8_t current_word = 0;
        
        while (std::getline(file, line) && current_block < NUMBER_OF_CACHE_BLOCKS) {
            // Clean the line
            line.erase(0, line.find_first_not_of(" \t\n\r\f\v"));
            line.erase(line.find_last_not_of(" \t\n\r\f\v") + 1);
            
            if (line.empty()) {
                continue;
            }

            // Process hexadecimal value
            try {
                // Remove 0x prefix if present
                if (line.size() > 2 && line[0] == '0' && (line[1] == 'x' || line[1] == 'X')) {
                    line = line.substr(2);
                }
                
                uint32_t value = std::stoul(line, nullptr, 16);
                
                // Ensure the block has space
                if (memory[current_block].data.size() < WORDS_PER_BLOCK) {
                    memory[current_block].data.resize(WORDS_PER_BLOCK);
                }
                
                memory[current_block].data[current_word] = value;
                memory[current_block].valid = true;
                
                current_word++;
                if (current_word >= WORDS_PER_BLOCK) {
                    current_word = 0;
                    current_block++;
                }
            } catch (...) {
                return false; // Conversion error
            }
        }
        
        return true;
    } catch (...) {
        return false; // Catch any unexpected exceptions
    }
}

bool CacheMemory::saveToFile(const std::string& filename) {
    try {
        std::ofstream file(filename);
        if (!file) {
            return false;
        }
        
        file << std::hex << std::uppercase << std::setfill('0');
        
        for (const auto& block : memory) {
            if (block.data.size() != WORDS_PER_BLOCK) {
                continue; // Block not initialized correctly
            }
            
            for (const auto& word : block.data) {
                file << "0x" << std::setw(8) << word << "\n";
                
                if (!file) {
                    return false; // Write error
                }
            }
        }
        
        return true;
    } catch (...) {
        return false; // Catch any unexpected exceptions
    }
}

void CacheMemory::showInfo() const {
    std::cout << "Cache Memory:\n";
    std::cout << " - Total blocks: " << std::dec << (int)NUMBER_OF_CACHE_BLOCKS << "\n";
    std::cout << " - Words per block: " << (int)WORDS_PER_BLOCK << "\n";
    std::cout << " - Word size: 32 bits (4 bytes)\n";
    std::cout << " - Total size: " << (NUMBER_OF_CACHE_BLOCKS * WORDS_PER_BLOCK * 4) << " bytes\n";
}
