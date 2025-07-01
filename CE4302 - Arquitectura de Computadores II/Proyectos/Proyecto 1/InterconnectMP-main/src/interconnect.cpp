#include "interconnect.hpp"
#include "processing_element.hpp"

Logger interconnet_logger("../resources/logs/interconnect_log.txt", false);
Logger interconnet_stats_logger("../resources/logs/interconnect_stats_log.txt", false);

Interconnect::Interconnect(SharedMemory& mem, bool use_qos) 
    : memory(mem), use_qos_arbitration(use_qos), running(true) {}

const InterconnectStats& Interconnect::getStats() {
    return stats;
}

void Interconnect::registerPE(ProcessingElement* pe) {
    pes.push_back(pe);
}

void Interconnect::setArbitrationScheme(bool use_qos) {
    use_qos_arbitration = use_qos;
}

void Interconnect::setSteppingMode(bool enable) {
    stepping_mode = enable;
}

void Interconnect::enqueueMessage(const Message& msg) {
    std::lock_guard<std::mutex> lock(queue_mutex);
    if (use_qos_arbitration) {
        qos_queue.push(msg);
    } else {
        fifo_queue.push(msg);
    }
}

void Interconnect::stopProcessing() {
    running = false;
}

void Interconnect::processMessages() {
    interconnet_logger.log("Started processing messages");

    while (running) { 
        size_t current_qsize = 0;
        Message msg;
        {
            std::lock_guard<std::mutex> lock(queue_mutex);
            current_qsize = use_qos_arbitration ? qos_queue.size() : fifo_queue.size();

            if (use_qos_arbitration) {
                if (qos_queue.empty()) continue;
                msg = qos_queue.top();
                qos_queue.pop();
            } else {
                if (fifo_queue.empty()) continue;
                msg = fifo_queue.front();
                fifo_queue.pop();
            }
        }

        stats.startProcessing();
        // Small delay to allow other PEs to send messages. Otherwise the queue size will always be 1
        std::this_thread::sleep_for(std::chrono::microseconds(10000)); 
        //std::cout << "queue size: " << ((use_qos_arbitration) ? qos_queue.size() : fifo_queue.size()) << std::endl;
        if (msg.addr % 4 != 0) {
            throw std::runtime_error("Address not aligned to 4 bytes");
        }

        interconnet_logger.log(messageToLog("Message received:", msg));

        // Process the message based on its type
        switch (msg.type) {
            case MessageType::READ_MEM: {
                Message resp{
                    MessageType::READ_RESP, 0xFF, msg.src, 0x0000, 0x0000, 0x00, 0x00, 0x00, 0x0, {}
                };

                uint32_t value;
                uint16_t pos = msg.addr / 4;
                for (uint16_t i = 0; i < msg.size; i++) {
                    value = memory.readByPosition(pos);
                    resp.data.push_back(value);
                    pos++;
                }
                resp.qos = msg.qos;
                resp.status = 0x1;
                
                stats.read_operations++;
                interconnet_logger.log(messageToLog("Message sent:", resp));
                pes[msg.src]->receiveMessage(resp); 
                break;
            }
            case MessageType::WRITE_MEM: {
                Message resp{
                    MessageType::WRITE_RESP, 0xFF, msg.src, 0x0000, 0x0000, 0x00, 0x00, 0x00, 0x0, {}
                };

                uint16_t pos = msg.addr / 4;
                for (uint32_t value : msg.data) {
                    memory.writeByPosition(pos, value);
                    pos++;
                }
                resp.qos = msg.qos;
                resp.status = 0x1;

                stats.write_operations++;
                interconnet_logger.log(messageToLog("Message sent:", resp));
                pes[msg.src]->receiveMessage(resp); 
                break;
            }
            case MessageType::BROADCAST_INVALIDATE: {
                Message resp{
                    MessageType::INV_COMPLETE, 0xFF, msg.src, 0x0000, 0x0000, 0x00, 0x00, 0x00, 0x0, {}
                };

                for (auto& pe : pes) {
                    if (pe->getID() == msg.src) continue; // Skip sender PE
                    pe->invalidateCacheBlock(msg.cache_line);
                }
                resp.cache_line = msg.cache_line;
                resp.qos = msg.qos;
                resp.status = 0x1;
                
                stats.invalidations++;
                interconnet_logger.log(messageToLog("Message sent:", resp));
                pes[msg.src]->receiveMessage(resp); 
                break;
            }
            default:
                // Handles unknown or unimplemented messages
                std::cerr << "Unknown type message received: " << static_cast<int>(msg.type) << std::endl;
                break;
        }
        stats.total_messages_processed++;
        stats.endProcessing(current_qsize);

        if (stepping_mode) {
            std::cout << "[Stepping mode] Press Enter to continue...\n";
            std::string input;
            std::getline(std::cin, input);
        }
    }

    interconnet_logger.log("Stopped processing messages");
    std::string arbitration = use_qos_arbitration ? "QoS" : "FIFO";
    interconnet_stats_logger.log(stats.getSummary(arbitration));
}
