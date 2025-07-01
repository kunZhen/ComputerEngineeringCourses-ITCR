#include "processing_element.hpp"
#include "interconnect.hpp"

Logger pes_logger("../resources/logs/pes_log.txt", false);
Logger pes_stats_logger("../resources/logs/pes_stats_log.txt", false);

// Initialization of the static counter
uint8_t ProcessingElement::next_id = 0;

void ProcessingElement::setReasons() {
    std::stringstream ss_mem_size;
    ss_mem_size << "0x" << std::hex << std::uppercase << std::setw(4) << std::setfill('0') << (SHARED_MEMORY_SIZE - 1) * 4;
    r_addr1 = "\n\treason: Address is out of range (0x0000 - " + ss_mem_size.str() + ")";
    r_addr2 = "\n\treason: Attempt to access an address after " + ss_mem_size.str();

    std::stringstream ss_cache_blocks;
    ss_cache_blocks << "0x" << std::hex << std::uppercase << std::setw(2) << std::setfill('0') << NUMBER_OF_CACHE_BLOCKS - 1;
    r_cache_block1 = "\n\treason: Attempt to invalidate a cache block out of range (0x00 - " + ss_cache_blocks.str() + ")";
    r_cache_block2 = "\n\treason: Attempt to access a cache block out of range (0x00 - " + ss_cache_blocks.str() + ")";

    std::stringstream ss_cache_size;
    ss_cache_size << "0x" << std::hex << std::uppercase << std::setw(4) << std::setfill('0') << NUMBER_OF_CACHE_BLOCKS * WORDS_PER_BLOCK;
    r_cache_size = "\n\treason: Size is out of range (0x0001 - " + ss_cache_size.str() + ")";
}

uint8_t ProcessingElement::getID() {
    return id;
}

uint8_t ProcessingElement::getQoS() {
    return qos;
}

const PEStats& ProcessingElement::getStats() {
    return stats;
}

void ProcessingElement::setCache(uint32_t seed) {
    cache.fillRandom(seed);
}

bool ProcessingElement::loadData(const std::string& filename) {
    return cache.loadFromFile(filename);
}

bool ProcessingElement::loadInstructions(const std::string& filename) {
    return instructions.loadFromFile(filename);
}

bool ProcessingElement::saveCache(const std::string& filename) {
    return cache.saveToFile(filename);
}

void ProcessingElement::saveStats() {
    stats.finalizeTiming(); // Ensure timing is up-to-date
    if (stats.total_msgs != 0) {
        pes_stats_logger.log(stats.getSummary(id));
    }
}

void ProcessingElement::sendMessage(Message& msg, Interconnect& interconnect) {
    auto start = std::chrono::high_resolution_clock::now();
    msg.src = id;
    msg.qos = qos;

    if (msg.addr % 4 != 0) {
        stats.recordDiscardedMessage();

        std::stringstream ss;
        ss << "0x" << std::hex << std::uppercase << std::setw(4) << std::setfill('0') << msg.addr;

        std::string message = messageToLog("Message discarded:", msg);
        message += "\n\treason: Address " + ss.str() + " not aligned to 4 bytes";

        pes_logger.log(message);
        throw std::runtime_error("[PE " + std::to_string((int)id) + "]: (Warning) A message was discarded");
    }

    if (msg.addr >= SHARED_MEMORY_SIZE * 4) {
        stats.recordDiscardedMessage();

        std::string message = messageToLog("Message discarded:", msg);
        message += r_addr1;

        pes_logger.log(message);
        throw std::runtime_error("[PE " + std::to_string((int)id) + "]: (Warning) A message was discarded");
    }

    u_int8_t block_index = 0;
    try {
        switch (msg.type) {
            case MessageType::WRITE_MEM: {
                block_index = msg.start_cache_line;
                u_int8_t end = msg.num_of_cache_lines;
                std::vector<uint32_t> block;
                
                if (msg.addr + (block_index + end) * 16 > SHARED_MEMORY_SIZE * 4) {
                    throw std::out_of_range("Address out of range");
                }
                if (block_index + end > NUMBER_OF_CACHE_BLOCKS) {
                    throw std::out_of_range("Block index out of range");
                }
    
                for (u_int8_t i = 0; i < end; i++) {
                    block = cache.readBlock(block_index);
                    msg.data.insert(msg.data.end(), block.begin(), block.end());
                    block_index++;
                }
                break;
            }
            case MessageType::READ_MEM: {
                if (msg.size >= SHARED_MEMORY_SIZE || msg.size >= NUMBER_OF_CACHE_BLOCKS * WORDS_PER_BLOCK) {
                    throw std::out_of_range("Size out of range");
                }
                if (msg.addr + msg.size * 4 > SHARED_MEMORY_SIZE * 4) {
                    throw std::out_of_range("Address out of range");
                }
                break;
            }
            case MessageType::BROADCAST_INVALIDATE: {
                if (msg.cache_line >= NUMBER_OF_CACHE_BLOCKS) {
                    throw std::out_of_range("Block index out of range");
                }
                break;
            }
            case MessageType::INV_ACK: {
                // No action needed for INV_ACK
                break;
            }
            default:
                // Handles unknown or unimplemented messages
                std::cerr << "Unknown type message received: " << static_cast<int>(msg.type) << std::endl;
                break;
        }
    } catch (const std::exception& e) {
        stats.recordDiscardedMessage();
        std::string message = messageToLog("Message discarded:", msg);

        if (std::string(e.what()) == "Block index out of range") {
            if (msg.type == MessageType::BROADCAST_INVALIDATE) {
                message += r_cache_block1;
            } else {
                message += r_cache_block2;
            }
        } else if (std::string(e.what()) == "Attempt to read an invalid block") {
            std::stringstream ss_cache_block;
            ss_cache_block << "0x" << std::hex << std::uppercase << std::setw(2) << std::setfill('0') << (int)block_index;

            message += "\n\treason: Attempt to read an invalid cache block (" + ss_cache_block.str() + ")";
        } else if (std::string(e.what()) == "Size out of range") {
            message += r_cache_size;
        } else if (std::string(e.what()) == "Address out of range") {
            message += r_addr2;
        }

        pes_logger.log(message);
        throw std::runtime_error("[PE " + std::to_string((int)id) + "]: (Warning) A message was discarded");
    }

    interconnect.enqueueMessage(msg);

    auto end = std::chrono::high_resolution_clock::now();
    double transfer_time = std::chrono::duration<double, std::micro>(end - start).count();    
    stats.recordSentMessage(calculateMessageSize(msg), transfer_time);
}

void ProcessingElement::receiveMessage(const Message& msg) {
    std::lock_guard<std::mutex> lock(msg_mutex);
    stats.recordReceivedMessage();
    incoming_messages.push(msg);
    msg_cv.notify_one(); // Notify waiting thread that a message is available
}

void ProcessingElement::invalidateCacheBlock(uint8_t cache_line) {
    cache.invalidateBlock(cache_line);
}

void ProcessingElement::processResponse(Message& msg) {
    switch (msg.type) {
        case MessageType::READ_RESP: {
            if (!msg.status) {
                std::cout << "[PE " << (int)id << "]: (Warning) READ_MEM was unsuccessful" << std::endl;
                break;
            }
            std::cout << "[PE " << (int)id << "]: (Info) READ_MEM was successful" << std::endl;

            if (msg.data.size() == 4) {
                cache.writeBlock(0, msg.data);
                break;
            }

            u_int8_t block_index = 0;
            u_int8_t word_offset = 0;
            while (!msg.data.empty()) {
                uint32_t word = msg.data.front();
                msg.data.erase(msg.data.begin());

                if (word_offset < WORDS_PER_BLOCK) {
                    cache.writeWord(block_index, word_offset, word);
                    word_offset++;
                } 
                else {
                    word_offset = 0;
                    block_index++;
                    cache.writeWord(block_index, word_offset, word);
                    word_offset++;
                }
            }
            break;
        }
        case MessageType::WRITE_RESP: {
            if (!msg.status) {
                std::cout << "[PE " << (int)id << "]: (Warning) WRITE_MEM was unsuccessful" << std::endl;
            }
            std::cout << "[PE " << (int)id << "]: (Info) WRITE_MEM was successful" << std::endl;
            break;
        }
        case MessageType::INV_COMPLETE: {
            std::cout << "[PE " << (int)id << "]: (Info) Other PEs have invalidated cache block: 0x" << std::hex << std::uppercase 
                      << std::setw(2) << std::setfill('0') << static_cast<int>(msg.cache_line) << std::endl;
            break;
        }
        default:
            // Handles unknown or unimplemented messages
            std::cerr << "Unknown type message received: " << static_cast<int>(msg.type) << std::endl;
            break;
    }
}

void ProcessingElement::process(Interconnect& interconnect) {
    stats.startActivePeriod(); // PE starts in active state

    while (instructions.hasInstructions()) {
        Message msg = instructions.nextInstruction();

        // Active period - sending message
        try {
            sendMessage(msg, interconnect);
        } catch (const std::exception& e) {
            std::cerr << e.what() << std::endl;
            continue;
        }

        // Transition to inactive while waiting
        stats.startInactivePeriod();

        // Blocking wait for the response
        std::unique_lock<std::mutex> lock(msg_mutex);
        msg_cv.wait(lock, [this] { return !incoming_messages.empty(); });

        // Transition back to active when processing response
        stats.startActivePeriod();
        
        Message resp = incoming_messages.front();
        incoming_messages.pop();
        processResponse(resp);
    }

    stats.finalizeTiming(); // Final time accounting
}
