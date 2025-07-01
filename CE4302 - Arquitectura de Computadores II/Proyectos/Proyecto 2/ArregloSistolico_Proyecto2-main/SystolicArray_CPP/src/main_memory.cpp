#include <fstream>
#include <sstream>
#include <iomanip>
#include <stdexcept>
#include "main_memory.hpp"

MainMemory::MainMemory() {
    memory.resize(MEM_SIZE_WORDS, 0);
}

void MainMemory::checkAlignment(uint32_t addr) const {
    if (addr % 4 != 0) throw std::runtime_error("Unaligned memory access");
    if (addr/4 >= MEM_SIZE_WORDS) throw std::out_of_range("Memory address out of range");
}

void MainMemory::writeWord(uint32_t addr, uint32_t data) {
    checkAlignment(addr);
    memory[addr/4] = data;
}

uint32_t MainMemory::readWord(uint32_t addr) const {
    checkAlignment(addr);
    return memory[addr/4];
}

void MainMemory::writeByte(uint32_t addr, uint8_t data) {
    if (addr >= MEM_SIZE_WORDS*4) throw std::out_of_range("Memory address out of range");
    
    uint32_t word_addr = addr & ~0x3;  // Align to word boundary
    uint32_t word = memory[word_addr/4];
    uint8_t shift = (addr % 4) * 8;
    
    word = (word & ~(0xFF << shift)) | (data << shift);
    memory[word_addr/4] = word;
}

uint8_t MainMemory::readByte(uint32_t addr) const {
    if (addr >= MEM_SIZE_WORDS*4) throw std::out_of_range("Memory address out of range");
    
    uint32_t word = memory[(addr & ~0x3)/4];
    return (word >> ((addr % 4) * 8)) & 0xFF;
}

void MainMemory::loadFromFile(const std::string& filename, uint32_t base_addr) {
    std::ifstream file(filename);
    if (!file.is_open()) throw std::runtime_error("Could not open image file");

    checkAlignment(base_addr);
    
    std::string line;
    
    // Read width and height (first two lines)
    std::getline(file, line);
    uint32_t width = std::stoul(line, nullptr, 16);
    std::getline(file, line);
    uint32_t height = std::stoul(line, nullptr, 16);
    
    // Write dimensions to memory (2 words)
    writeWord(base_addr, width);
    writeWord(base_addr + 4, height);
    
    // Read pixel data (each line is one word)
    uint32_t addr = base_addr + 8;
    while (std::getline(file, line)) {
        if (line.empty()) continue;
        uint32_t pixel_block = std::stoul(line, nullptr, 16);
        writeWord(addr, pixel_block);
        addr += 4;
    }
}

void MainMemory::saveImage(const std::string& filename, uint32_t base_addr) {
    std::ofstream file(filename);
    if (!file.is_open()) throw std::runtime_error("Could not create image file");

    checkAlignment(base_addr);
    
    // Read dimensions
    uint32_t width = readWord(base_addr);
    uint32_t height = readWord(base_addr + 4);
    
    // Write header
    file << std::hex << std::setw(8) << std::setfill('0') << width << "\n";
    file << std::hex << std::setw(8) << std::setfill('0') << height << "\n";
    
    // Write pixel data
    uint32_t addr = base_addr + 8;
    uint32_t total_pixels = width * height;
    uint32_t words_needed = (total_pixels + 3) / 4;  // Round up
    
    for (uint32_t i = 0; i < words_needed; ++i) {
        uint32_t pixel_block = readWord(addr);
        file << std::hex << std::setw(8) << std::setfill('0') << pixel_block << "\n";
        addr += 4;
    }
}