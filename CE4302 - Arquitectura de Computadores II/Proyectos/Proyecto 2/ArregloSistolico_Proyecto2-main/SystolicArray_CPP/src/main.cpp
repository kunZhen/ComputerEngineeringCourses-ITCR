#include <iostream>
#include "main_memory.hpp"
#include "image_processor.hpp"
#include "systolic_array.hpp"
#include <iomanip>

int main() {
    try {
        std::cout << "Create input.txt from a selected image\n";
        const std::string python_cmd1 = "/bin/python3 ../python/image_to_memory.py";
        int result1 = std::system(python_cmd1.c_str());
        
        if (result1 != 0) {
            std::cerr << "Warning: Failed to execute image_to_memory.py (Error code: " 
                    << result1 << ")\n";
            return 1;
        }

        std::ofstream clear_log("../resources/files/logs.txt", std::ios::out);
        clear_log.close();

        const uint32_t WEIGHTS_ADDR = 0x00000000;
        const uint32_t INPUT_ADDR = 0x00000100;
        const uint32_t OUTPUT_ADDR = 0x00010000;

        // Instantiate main memory
        MainMemory memory;

        // Load weights and image
        memory.loadFromFile("../resources/files/weights.txt", WEIGHTS_ADDR);  
        memory.loadFromFile("../resources/files/input.txt", INPUT_ADDR);    

        uint32_t width;
        uint32_t height;
        
        // Check some values
        std::cout << "\n=== Weight Verification ===" << std::endl;
        width = memory.readWord(WEIGHTS_ADDR);
        height = memory.readWord(WEIGHTS_ADDR + 4);
        std::cout << "Dimensions of the weight array: " << width << " x " << height << std::endl;
        for (uint32_t i = 0; i < 4; i++) {
            uint32_t word = memory.readWord(WEIGHTS_ADDR + 8 + i * 4);
            std::cout << "Weights in direction " << (i * 4) << ": 0x" 
                      << std::hex << std::setw(8) << std::setfill('0') << word << std::endl;
        }
        
        std::cout << "\n=== Input Image Verification ===" << std::endl;
        width = memory.readWord(INPUT_ADDR);
        height = memory.readWord(INPUT_ADDR + 4);
        std::cout << "Image dimensions: " << std::dec << width << " x " << std::dec << height << std::endl;
        
        // Show first 4 blocks of pixels
        for (uint32_t i = 0; i < 4; i++) {
            uint32_t pixel_block = memory.readWord(INPUT_ADDR + 8 + i * 4);
            std::cout << "Block of pixels " << i << ": 0x" 
                      << std::hex << std::setw(8) << std::setfill('0') << pixel_block << std::endl;
        }

        // Instantiate systolic array
        SystolicArray systolic(4, memory, WEIGHTS_ADDR);

        // Instantiate image processor
        ImageProcessor img_proc(memory);

        // Process image
        img_proc.processImage(systolic, INPUT_ADDR, OUTPUT_ADDR);
        
        memory.saveImage("../resources/files/output.txt", OUTPUT_ADDR);
        std::cout << "\nSaving results to output.txt and creating an image" << std::endl;

        const std::string python_cmd2 = "/bin/python3 ../python/memory_to_image.py";
        int result2 = std::system(python_cmd2.c_str());
        
        if (result2 != 0) {
            std::cerr << "Warning: Failed to execute memory_to_image.py (Error code: " 
                    << result2 << ")\n";
            return 1;
        }

    } catch (const std::exception& e) {
        std::cerr << "Error: " << e.what() << std::endl;
        return 1;
    }

    return 0;
}