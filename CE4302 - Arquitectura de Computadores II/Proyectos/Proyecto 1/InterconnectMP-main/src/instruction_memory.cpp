#include "instruction_memory.hpp"

bool InstructionMemory::loadFromFile(const std::string& filename) {
    std::ifstream file(filename);
    if (!file.is_open()) {
        return false;
    }

    std::map<std::string, MessageType> instructionMap = {
        {"WRITE_MEM", MessageType::WRITE_MEM},
        {"READ_MEM", MessageType::READ_MEM},
        {"BROADCAST_INVALIDATE", MessageType::BROADCAST_INVALIDATE}
    };

    std::string line;
    while (std::getline(file, line)) {
        // Remove comments
        size_t commentPos = line.find("//");
        if (commentPos != std::string::npos) {
            line = line.substr(0, commentPos);
        }

        // Remove leading and trailing whitespaces
        line.erase(0, line.find_first_not_of(" \t"));
        line.erase(line.find_last_not_of(" \t") + 1);

        // Skip empty lines
        if (line.empty()) {
            continue;
        }

        // Convert to uppercase
        std::string upperLine = line;
        std::transform(upperLine.begin(), upperLine.end(), upperLine.begin(),
                       [](unsigned char c){ return std::toupper(c); });

        // Process the line
        std::istringstream iss(upperLine);
        std::string instructionType;
        iss >> instructionType;

        Message msg; // Default values
        msg.type = instructionMap[instructionType];
        msg.src = 0xFF;
        msg.dest = 0xFF;
        msg.addr = 0x0000;
        msg.size = 0x0000;
        msg.cache_line = 0x00;
        msg.start_cache_line = 0x00;
        msg.num_of_cache_lines = 0x00;
        msg.qos = 0x00;
        msg.status = 0x0;
        msg.data = {};

        try {
            switch (msg.type) {
                case MessageType::WRITE_MEM: {
                    // Format: WRITE_MEM addr, start_cache_line, num_of_cache_lines
                    std::string addrStr, startStr, numStr;
                    
                    iss >> std::hex >> addrStr 
                        >> std::hex >> startStr
                        >> std::hex >> numStr;
                    
                    // Remove 0x if exists
                    addrStr = (addrStr.size() >= 2 && addrStr.find("0X") == 0) ? addrStr.substr(2) : addrStr;
                    startStr = (startStr.size() >= 2 && startStr.find("0X") == 0) ? startStr.substr(2) : startStr;
                    numStr = (numStr.size() >= 2 && numStr.find("0X") == 0) ? numStr.substr(2) : numStr;
                    
                    // Remove comma if exists
                    addrStr = (addrStr.size() > 0 && addrStr.back() == ',') ? addrStr.substr(0, addrStr.size() - 1) : addrStr;
                    startStr = (startStr.size() > 0 && startStr.back() == ',') ? startStr.substr(0, startStr.size() - 1) : startStr;
                    numStr = (numStr.size() > 0 && numStr.back() == ',') ? numStr.substr(0, numStr.size() - 1) : numStr;
                    
                    msg.addr = static_cast<uint16_t>(std::stoul(addrStr, nullptr, 16));
                    msg.start_cache_line = static_cast<uint8_t>(std::stoul(startStr, nullptr, 16));
                    msg.num_of_cache_lines = static_cast<uint8_t>(std::stoul(numStr, nullptr, 16));

                    break;
                }
                case MessageType::BROADCAST_INVALIDATE: {
                    // Format: BROADCAST_INVALIDATE cache_line
                    std::string cacheLineStr;
                    iss >> std::hex >> cacheLineStr;
                    
                    if (cacheLineStr.find("0X") == 0) {
                        cacheLineStr = cacheLineStr.substr(2);
                    }
                    
                    msg.cache_line = static_cast<uint8_t>(std::stoul(cacheLineStr, nullptr, 16));
                    break;
                }
                case MessageType::READ_MEM: {
                    // Format: READ_MEM addr, size
                    std::string addrStr, sizeStr;
                    
                    iss >> std::hex >> addrStr >> std::hex >> sizeStr;
                    
                    // Remove 0x if exists
                    addrStr = (addrStr.size() >= 2 && addrStr.find("0X") == 0) ? addrStr.substr(2) : addrStr;
                    sizeStr = (sizeStr.size() >= 2 && sizeStr.find("0X") == 0) ? sizeStr.substr(2) : sizeStr;
                    
                    msg.addr = static_cast<uint16_t>(std::stoul(addrStr, nullptr, 16));
                    msg.size = static_cast<uint16_t>(std::stoul(sizeStr, nullptr, 16));
                    break;
                }
                default:
                    continue; // Unknown instruction type
            }
            
            instructions.push(msg);
        } catch (...) {
            // Error processing the line - continue with the next
            continue;
        }
    }

    return true;
}

void InstructionMemory::loadInstructions(const std::vector<Message>& msgs) {
    for (const auto& msg : msgs) {
        instructions.push(msg);
    }
}

Message InstructionMemory::nextInstruction() {
    Message msg = instructions.front();
    instructions.pop();
    return msg;
}

bool InstructionMemory::hasInstructions() const {
    return !instructions.empty();
}
