#include <random>
#include <stdexcept>
#include "shared_memory.hpp"

void SharedMemory::writeByAddress(uint16_t addr, uint32_t value) {
    // Check if address is aligned to 4 bytes
    if (addr % 4 != 0) {
        throw std::runtime_error("Address not aligned to 4 bytes");
    }
    
    uint16_t pos = addr / 4;
    if (pos >= SHARED_MEMORY_SIZE) {
        throw std::out_of_range("Position out of range");
    }
    
    std::lock_guard<std::mutex> lock(mem_mutex);
    memory[pos] = value;
}

void SharedMemory::writeByPosition(uint16_t pos, uint32_t value) {
    if (pos >= SHARED_MEMORY_SIZE) {
        throw std::out_of_range("Position out of range");
    }
    
    std::lock_guard<std::mutex> lock(mem_mutex);
    memory[pos] = value;
}

uint32_t SharedMemory::readByAddress(uint16_t addr) {
    // Check if address is aligned to 4 bytes
    if (addr % 4 != 0) {
        throw std::runtime_error("Address not aligned to 4 bytes");
    }
    
    uint16_t pos = addr / 4;
    if (pos >= SHARED_MEMORY_SIZE) {
        throw std::out_of_range("Position out of range");
    }
    
    std::lock_guard<std::mutex> lock(mem_mutex);
    return memory[pos];
}

uint32_t SharedMemory::readByPosition(uint16_t pos) {
    if (pos >= SHARED_MEMORY_SIZE) {
        throw std::out_of_range("Position out of range");
    }
    
    std::lock_guard<std::mutex> lock(mem_mutex);
    return memory[pos];
}

void SharedMemory::fillRandom(uint32_t seed) {
    std::lock_guard<std::mutex> lock(mem_mutex);
    
    std::mt19937 gen(seed);
    std::uniform_int_distribution<uint32_t> dist;
    
    for (auto& word : memory) {
        word = dist(gen);
    }
}

bool SharedMemory::loadFromFile(const std::string& filename) {
    try {
        std::ifstream file(filename);
        if (!file) {
            return false;
        }

        std::lock_guard<std::mutex> lock(mem_mutex);
        
        std::string line;
        size_t pos = 0;
        
        while (std::getline(file, line)) {
            // Remove leading and trailing whitespace
            line.erase(0, line.find_first_not_of(" \t\n\r\f\v"));
            line.erase(line.find_last_not_of(" \t\n\r\f\v") + 1);
            
            // Skip empty lines
            if (line.empty()) {
                continue;
            }
            
            // Check if memory size was exceeded
            if (pos >= SHARED_MEMORY_SIZE) {
                return false; // Too much data in the file
            }
            
            // Process hexadecimal line (accepts formats like "0x1234ABCD" or "1234ABCD")
            try {
                size_t processed = 0;
                uint32_t value;
                
                // Remove 0x prefix if present
                if (line.size() > 2 && line[0] == '0' && (line[1] == 'x' || line[1] == 'X')) {
                    line = line.substr(2);
                }
                
                // Convert from hexadecimal string to uint32_t
                value = std::stoul(line, &processed, 16);
                
                // Check if the entire line was processed
                if (processed != line.size()) {
                    return false; // Invalid characters in the line
                }
                
                memory[pos++] = value;
            } catch (const std::exception&) {
                return false; // Conversion error
            }
        }
        
        return true;
    } catch (...) {
        return false; // Catch any unexpected exceptions
    }
}

bool SharedMemory::saveToFile(const std::string& filename) {
    try {
        std::ofstream file(filename);
        if (!file) {
            return false;
        }
        
        std::lock_guard<std::mutex> lock(mem_mutex);
        
        file << std::hex << std::uppercase << std::setfill('0');
        for (const auto& word : memory) {
            file << "0x" << std::setw(8) << word << "\n";
            
            if (!file) {
                return false; // Error during writing
            }
        }
        
        return true;
    } catch (...) {
        return false; // Catch any unexpected exceptions
    }
}

void SharedMemory::showInfo() const {
    std::cout << "Shared Memory:\n";
    std::cout << " - Total positions: " << SHARED_MEMORY_SIZE << "\n";
    std::cout << " - Size per position: 32 bits (4 bytes)\n";
    std::cout << " - Total size: " << (SHARED_MEMORY_SIZE * 4) << " bytes\n";
    std::cout << " - Alignment: 4 bytes\n";
}
