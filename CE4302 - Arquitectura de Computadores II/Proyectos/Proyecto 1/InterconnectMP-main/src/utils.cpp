#include "utils.hpp"

void printMessage(const Message& msg) {
    std::cout << "\ntype: ";
    switch (msg.type) {
        case MessageType::WRITE_MEM: std::cout << "WRITE_MEM"; break;
        case MessageType::READ_MEM: std::cout << "READ_MEM"; break;
        case MessageType::BROADCAST_INVALIDATE: std::cout << "BROADCAST_INVALIDATE"; break;
        default: std::cout << "UNKNOWN (" << static_cast<int>(msg.type) << ")"; break;
    }
    std::cout << "\n";

    std::cout << "src: 0x" << std::hex << std::uppercase << std::setw(2) << std::setfill('0') 
              << static_cast<int>(msg.src) << std::dec << "\n";

    std::cout << "dest: 0x" << std::hex << std::uppercase << std::setw(2) 
              << static_cast<int>(msg.dest) << std::dec << "\n";

    if (msg.type == MessageType::WRITE_MEM || msg.type == MessageType::READ_MEM) {
        std::cout << "addr: 0x" << std::hex << std::uppercase << std::setw(4) 
                  << msg.addr << std::dec << "\n";
    }
    
    if (msg.type == MessageType::READ_MEM) {
        std::cout << "size: 0x" << std::hex << std::uppercase << std::setw(4) 
                  << msg.size << std::dec << "\n";
    }

    if (msg.type == MessageType::WRITE_MEM) {
        std::cout << "start_cache_line: 0x" << std::hex << std::uppercase << std::setw(2) << std::setfill('0') 
                  << static_cast<int>(msg.start_cache_line) << std::dec << "\n";
        std::cout << "num_of_cache_lines: 0x" << std::hex << std::uppercase << std::setw(2) << std::setfill('0') 
                  << static_cast<int>(msg.num_of_cache_lines) << std::dec << "\n";
    }

    if (msg.type == MessageType::BROADCAST_INVALIDATE) {
        std::cout << "cache_line: 0x" << std::hex << std::uppercase << std::setw(2) << std::setfill('0')
                  << static_cast<int>(msg.cache_line) << std::dec << "\n";
    }

    std::cout << "qos: 0x" << std::hex << std::uppercase << std::setw(2) << std::setfill('0')
              << static_cast<int>(msg.qos) << "\n";

    std::cout << "status: 0x" << static_cast<int>(msg.status) << "\n";

    if (!msg.data.empty()) {
        std::cout << "data: ";
        for (uint32_t word : msg.data) {
            std::cout << "0x" << std::hex << std::uppercase << std::setw(8) << std::setfill('0') << word << " ";
        }
        std::cout << std::dec << "\n";
    }
}

std::string messageToLog(const std::string& begin, const Message& msg) {
    std::stringstream ss;
    ss << "\n\ttype: ";
    
    switch(msg.type) {
        case MessageType::READ_MEM: ss << "READ_MEM"; break;
        case MessageType::WRITE_MEM: ss << "WRITE_MEM"; break;
        case MessageType::BROADCAST_INVALIDATE: ss << "BROADCAST_INVALIDATE"; break;
        case MessageType::READ_RESP: ss << "READ_RESP"; break;
        case MessageType::WRITE_RESP: ss << "WRITE_RESP"; break;
        case MessageType::INV_COMPLETE: ss << "INV_COMPLETE"; break;
        default: ss << "UNKNOWN"; break;
    }
    
    ss << " | src: 0x" << std::hex << std::uppercase << std::setw(2) << std::setfill('0') << static_cast<int>(msg.src) << std::dec
       << " | dest: 0x" << std::hex << std::uppercase << std::setw(2) << static_cast<int>(msg.dest) << std::dec;

    if (msg.type == MessageType::WRITE_MEM || msg.type == MessageType::READ_MEM) {
        ss << " | addr: 0x" << std::hex << std::uppercase << std::setw(4) << msg.addr << std::dec;
    }

    if (msg.type == MessageType::READ_MEM) {
        ss << " | size: 0x" << std::hex << std::uppercase << std::setw(4) << msg.size << std::dec;
    }

    if (msg.type == MessageType::WRITE_MEM) {
        ss << " | start_cache_line: 0x" << std::hex << std::uppercase << std::setw(2) << std::setfill('0') 
                << static_cast<int>(msg.start_cache_line) << std::dec;
                  
        ss << " | num_of_cache_lines: 0x" << std::hex << std::uppercase << std::setw(2) << std::setfill('0') 
                << static_cast<int>(msg.num_of_cache_lines) << std::dec;
    }

    if (msg.type == MessageType::BROADCAST_INVALIDATE || msg.type == MessageType::INV_COMPLETE) {
        ss << " | cache_line: 0x" << std::hex << std::uppercase << std::setw(2) << std::setfill('0')
                << static_cast<int>(msg.cache_line) << std::dec;
    }

    ss << " | qos: 0x" << std::hex << std::uppercase << std::setw(2) << std::setfill('0') 
                << static_cast<int>(msg.qos);

    ss << " | status: 0x" << static_cast<int>(msg.status);

    uint16_t count = 0;
    if (!msg.data.empty()) {
        ss << "\n\tdata: ";
        for (uint32_t word : msg.data) {
            if (count < 8) {
                ss << "0x" << std::hex << std::uppercase << std::setw(8) << std::setfill('0') << word << " ";
            }
            else {
                ss << "\n\t      0x" << std::hex << std::uppercase << std::setw(8) << std::setfill('0') << word << " ";
                count = 0;
            }
            count++;
        }
        std::cout << std::dec;
    }
    
    return begin + ss.str();
}

size_t calculateMessageSize(const Message& msg) {
    return sizeof(Message) + (msg.data.size() * sizeof(uint32_t));
}

std::vector<uint8_t> loadQoS(const std::string& filename) {
    std::vector<uint8_t> pes_qos;
    std::ifstream file(filename);

    if (!file.is_open()) {
        throw std::runtime_error("Failed to open file: " + filename);
    }
    
    std::string line;
    while (std::getline(file, line)) {
        // Ignore empty lines or lines starting with "#"
        if (line.empty() || line[0] == '#') {
            continue;
        }

        std::istringstream iss(line);
        std::string token, value_str;
        iss >> token >> value_str; // Read "PEX:" and the value

        // Extract the hexadecimal value
        if (value_str.find("0x") != std::string::npos) {
            try {
                uint8_t value = static_cast<uint8_t>(std::stoul(value_str, 0, 16));
                pes_qos.push_back(value);
            } catch (const std::invalid_argument& e) {
                throw std::invalid_argument("Invalid value: " + value_str);
            }
        }
    }

    file.close();
    return pes_qos;
}