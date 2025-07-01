#include <thread>
#include <memory>
#include <vector>
#include <string>
#include <random>
#include <algorithm>
#include <iostream>
#include <stdexcept>
#include "processing_element.hpp"
#include "interconnect.hpp"
#include "shared_memory.hpp"

/**
 * Displays program usage instructions
 * @param program_name The name of the executable
 */
void show_usage(const std::string& program_name) {
    std::cerr << "Usage: " << program_name << " [OPTIONS]\n"
              << "Options:\n"
              << "  -n, --num-pes NUM    Number of PEs to create (" << (int)MIN_NUM_PES 
              << "-" << (int)MAX_NUM_PES <<", default: " << (int)DEFAULT_NUM_PES << ")\n"
              << "  -s, --scheme SCHEME  Arbitration scheme (fifo|qos, default: fifo)\n"
              << "  -t, --stepping       Enable step-by-step execution mode\n"
              << "  -h, --help           Show this help message\n";
}

bool getUserConfirmation(const std::string& prompt) {
    std::string input;
    while (true) {
        std::cout << prompt << " [y/n]: ";
        std::getline(std::cin, input);
        
        if (input == "y" || input == "Y") {
            return true;
        } else if (input == "n" || input == "N") {
            return false;
        }
        
        std::cout << "Invalid input. Please enter 'y' for yes or 'n' for no.\n";
    }
}

/**
 * Main simulation program
 * @param argc Argument count
 * @param argv Argument values
 * @return Exit status (0 = success)
 */
int main(int argc, char* argv[]) {
    // Default configuration values
    int num_pes = DEFAULT_NUM_PES;
    bool use_qos = false;
    bool stepping_mode = false;

    // QoS values for PEs
    std::vector<uint8_t> pes_qos;
    try {
        pes_qos = loadQoS("../resources/config/qos_config.txt");
    } catch (const std::exception& e) {
        std::cerr << e.what() << std::endl;
        return 1;
    }

    // Parse command-line arguments
    for (int i = 1; i < argc; ++i) {
        std::string arg = argv[i];
        if (arg == "-h" || arg == "--help") {
            show_usage(argv[0]);
            return 0;
        } else if (arg == "-n" || arg == "--num-pes") {
            if (i + 1 < argc) {
                try {
                    num_pes = std::stoi(argv[++i]);
                    if (num_pes < MIN_NUM_PES || num_pes > MAX_NUM_PES) {
                        std::string mensaje = "Number of PEs must be between " + 
                        std::to_string(MIN_NUM_PES) + " and " + std::to_string(MAX_NUM_PES);

                        throw std::out_of_range(mensaje);
                    }
                } catch (const std::exception& e) {
                    std::cerr << "Error: Invalid argument for --num-pes: " << e.what() << "\n";
                    show_usage(argv[0]);
                    return 1;
                }
            } else {
                std::cerr << "Error: Missing argument for --num-pes\n";
                show_usage(argv[0]);
                return 1;
            }
        } else if (arg == "-s" || arg == "--scheme") {
            if (i + 1 < argc) {
                std::string scheme = argv[++i];
                if (scheme == "qos") {
                    use_qos = true;
                } else if (scheme != "fifo") {
                    std::cerr << "Error: Invalid scheme. Use 'fifo' or 'qos'\n";
                    show_usage(argv[0]);
                    return 1;
                }
            } else {
                std::cerr << "Error: Missing argument for --scheme\n";
                show_usage(argv[0]);
                return 1;
            }
        } else if (arg == "-t" || arg == "--stepping") {
            stepping_mode = true;
        } else {
            std::cerr << "Error: Unknown argument '" << arg << "'\n";
            show_usage(argv[0]);
            return 1;
        }
    }

    try {
        // Initialize shared memory
        SharedMemory memory;

        if (!memory.loadFromFile("../resources/shared_memory/data.txt")) {
            throw std::runtime_error("Failed to load memory contents from file");
        }

        // Create interconnect with selected scheme
        std::cout << "Creating Interconnect with " << (use_qos ? "QoS" : "FIFO") << " arbitration\n";
        Interconnect interconnect(memory, use_qos);
        
        if (stepping_mode) {
            interconnect.setSteppingMode(stepping_mode);
            std::cout << "Stepping mode enabled\n";
        }

        // Create Processing Elements
        std::cout << "Initializing " << num_pes << " PEs...\n";
        std::vector<std::unique_ptr<ProcessingElement>> pes;
        std::vector<std::thread> pe_threads;

        for (int i = 0; i < num_pes; ++i) {
            auto pe = std::make_unique<ProcessingElement>(pes_qos[i]);

            std::string instructions_file = "../resources/pe_instructions/inst_pe_" + std::to_string(i) + ".txt";
            if (!pe->loadInstructions(instructions_file)) {
                std::cerr << "Warning: Failed to load instructions for PE " << i << "\n";
            }
            
            pe->setCache(i);
            pes.push_back(std::move(pe));
        }

        // Register PEs with interconnect
        for (auto& pe : pes) {
            interconnect.registerPE(pe.get());
        }
        
        // Start interconnect thread
        std::cout << "\nSimulation start\n";
        std::thread interconnect_thread([&interconnect]() {
            interconnect.processMessages();
        });

        //// Start PE threads
        //for (auto& pe : pes) {
        //    pe_threads.emplace_back([&interconnect, pe_ptr = pe.get()]() {
        //        pe_ptr->process(interconnect);
        //    });
        //}

        // Create a vector of indices for random access
        std::vector<uint8_t> pe_indices(pes.size());
        std::iota(pe_indices.begin(), pe_indices.end(), 0);

        // Shuffle the indices for random execution order
        std::random_device rd;
        std::mt19937 g(rd());
        std::shuffle(pe_indices.begin(), pe_indices.end(), g);

        // Start PE threads in random order
        for (uint8_t idx : pe_indices) {
            pe_threads.emplace_back([&interconnect, pe_ptr = pes[idx].get()]() {
                pe_ptr->process(interconnect);
            });
            
            // Add random delay between thread launches (0-10ms)
            std::this_thread::sleep_for(
                std::chrono::milliseconds(std::uniform_int_distribution<>(0, 10)(g))
            );
        }

        // Wait for all PEs to complete
        for (auto& thread : pe_threads) {
            thread.join();
        }

        // Clean shutdown
        interconnect.stopProcessing();
        interconnect_thread.join();

        // Save cache states and stats for all PEs
        for (auto& pe : pes) {
            std::string cache_file = "../resources/pe_cache/cache_pe_" + std::to_string(pe->getID()) + ".txt";
            if (!pe->saveCache(cache_file)) {
                std::cerr << "Warning: Failed to save cache state for PE " << pe->getID() << "\n";
            }
            pe->saveStats();
        }

        std::cout << "\nSimulation completed successfully!\n";

        // Ask user if they want to visualize results
        if (getUserConfirmation("\nShow system results?")) {
            const std::string python_cmd = "/bin/python3 ../resources/graphics/graphic_results.py";
            
            std::cout << "Generating visualizations...\n";
            int result = std::system(python_cmd.c_str());
            
            if (result != 0) {
                std::cerr << "Warning: Failed to execute visualization script (Error code: " 
                        << result << ")\n";
                return 1;
            }
        } else {
            std::cout << "Results visualization skipped.\n";
        }

        return 0;

    } catch (const std::exception& e) {
        std::cerr << "Fatal Error: " << e.what() << "\n";
        return 1;
    }
}
