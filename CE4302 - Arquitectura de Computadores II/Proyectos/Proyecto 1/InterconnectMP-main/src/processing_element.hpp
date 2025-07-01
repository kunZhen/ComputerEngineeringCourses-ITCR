#ifndef PROCESSING_ELEMENT_HPP
#define PROCESSING_ELEMENT_HPP

#include <iostream>
#include <queue>
#include <mutex>
#include <condition_variable>
#include "cache_memory.hpp"
#include "instruction_memory.hpp"
#include "message.hpp"
#include "utils.hpp"

// Forward declaration
class Interconnect;

static std::string r_addr1;
static std::string r_addr2;
static std::string r_cache_block1;
static std::string r_cache_block2;
static std::string r_cache_size;

/**
 * @brief Structure to save stats of the processing element
 */
struct PEStats {
    // Message counters
    size_t total_msgs = 0;       // Total messages handled
    size_t sent_msgs = 0;        // Successfully sent to interconnect
    size_t received_msgs = 0;    // Received from interconnect
    size_t discarded_msgs = 0;   // Failed messages (alignment/size errors, etc)

    // Timing and size data
    std::vector<double> message_transfer_times; // In microseconds
    std::vector<size_t> message_sizes;          // In bytes

    // Timing metrics
    std::chrono::microseconds active_time{0};
    std::chrono::microseconds inactive_time{0};
    std::chrono::time_point<std::chrono::high_resolution_clock> last_state_change;

    // Utility methods
    void recordSentMessage(size_t size, double transfer_time) {
        total_msgs++;
        sent_msgs++;
        message_sizes.push_back(size);
        message_transfer_times.push_back(transfer_time);
    }

    void recordReceivedMessage() {
        received_msgs++;
    }

    void recordDiscardedMessage() {
        total_msgs++;
        discarded_msgs++;
    }

    void startActivePeriod() {
        auto now = std::chrono::high_resolution_clock::now();
        if (last_state_change.time_since_epoch().count()) {
            inactive_time += std::chrono::duration_cast<std::chrono::microseconds>(
                now - last_state_change);
        }
        last_state_change = now;
    }

    void startInactivePeriod() {
        auto now = std::chrono::high_resolution_clock::now();
        if (last_state_change.time_since_epoch().count()) {
            active_time += std::chrono::duration_cast<std::chrono::microseconds>(
                now - last_state_change);
        }
        last_state_change = now;
    }

    void finalizeTiming() {
        auto now = std::chrono::high_resolution_clock::now();
        if (last_state_change.time_since_epoch().count()) {
            active_time += std::chrono::duration_cast<std::chrono::microseconds>(
                now - last_state_change);
        }
    }

    std::string getSummary(uint8_t id) const {
        // Calculate averages
        double avg_transfer_time = message_transfer_times.empty() ? 0.0 :
            std::accumulate(message_transfer_times.begin(), 
                          message_transfer_times.end(), 0.0) 
            / message_transfer_times.size();

        double avg_msg_size = message_sizes.empty() ? 0.0 :
            std::accumulate(message_sizes.begin(), 
                          message_sizes.end(), 0.0) 
            / message_sizes.size();

        // Calculate time percentages
        double total_time = (active_time + inactive_time).count();
        double active_percent = total_time > 0 ? 
            (100.0 * active_time.count() / total_time) : 0.0;
        double inactive_percent = 100.0 - active_percent;

        // Format output
        std::stringstream ss;
        ss << std::fixed << std::setprecision(2);
        ss << "\n============ PE " << (int)id << " Stats ============\n"
                  << "Total Messages:      " << total_msgs << "\n"
                  << "  Sent:              " << sent_msgs 
                  << " (" << (100.0*sent_msgs/total_msgs) << "%)\n"
                  << "  Received:          " << received_msgs << "\n"
                  << "  Discarded:         " << discarded_msgs 
                  << " (" << (100.0*discarded_msgs/total_msgs) << "%)\n\n"
                  << "Transfer Times (μs):\n"
                  << "  Average:           " << avg_transfer_time << "\n"
                  << "  Min:               " 
                  << *std::min_element(message_transfer_times.begin(), 
                                     message_transfer_times.end()) << "\n"
                  << "  Max:               " 
                  << *std::max_element(message_transfer_times.begin(), 
                                     message_transfer_times.end()) << "\n\n"
                  << "Message Sizes (bytes):\n"
                  << "  Average:           " << avg_msg_size << "\n"
                  << "  Total:             " 
                  << std::accumulate(message_sizes.begin(), 
                                    message_sizes.end(), 0) << "\n"
                  << "\nTime Analysis (μs):\n"
                  << "  Active:            " << active_time.count() 
                  << " (" << active_percent << "%)\n"
                  << "  Inactive:          " << inactive_time.count()
                  << " (" << inactive_percent << "%)\n"
                  << "  Total:             " << total_time << "\n"
                  << "====================================";
        
        return ss.str();
    }
};

/**
 * @brief Class representing a processing element in a multi-core system.
 *
 * Each processing element has its own ID, QoS, cache memory, instruction memory,
 * and message handling capabilities.
 */
class ProcessingElement {
private:
    static uint8_t next_id;                 // Static counter for automatic ID assignment
    uint8_t id;                             // ID of the PE
    uint8_t qos;                            // Priority of the PE (e.g. 0x00-0xFF)
    CacheMemory cache;                      // 128 blocks * 16 bytes = 2048 bytes
    InstructionMemory instructions;         // Workload of the PE
    std::queue<Message> incoming_messages;  // Messages received
    std::mutex msg_mutex;                   // Mutex for protecting incoming messages queue
    std::condition_variable msg_cv;         // Condition variable for signaling new messages
    PEStats stats;                          // Stats of the PE

public:
    /**
     * @brief Constructor for the ProcessingElement class.
     *
     * @param id_  The ID of the processing element.
     * @param qos_ The QoS (priority) of the processing element.
     */
    ProcessingElement(uint8_t qos_) : id(next_id++), qos(qos_) {
        setReasons();
    }

    /**
     * @brief Define some basic messages to be added to the PE log if needed.
     */
    void setReasons();

    /**
     * @brief Gets the ID of the processing element.
     *
     * @return The ID of the processing element.
     */
    uint8_t getID();

    /**
     * @brief Gets the QoS of the processing element.
     *
     * @return The QoS of the processing element.
     */
    uint8_t getQoS();

    /**
     * @brief Gets the PEStats struct of the processing element.
     *
     * @return The PEStats struct of the processing element.
     */
    const PEStats& getStats();

    /**
     * @brief Fills the entire cache with random values.
     *
     * @param seed Seed for random number generator.
     */
    void setCache(uint32_t seed);

    /**
     * @brief Loads cache contents from a file.
     * 
     * @param filename Path to file containing hexadecimal data
     * @return True if load was successful, false otherwise
     */
    bool loadData(const std::string& filename);

    /**
     * @brief Loads instructions from a file into the instruction queue.
     *
     *
     * @param filename The name of the file to load instructions from.
     * @return true if the file was loaded successfully, false otherwise.
     */
    bool loadInstructions(const std::string& filename);

    /**
     * @brief Saves cache contents to a file.
     * 
     * @param filename Path to output file.
     * @return True if save was successful, false otherwise.
     */
    bool saveCache(const std::string& filename);

     /**
     * @brief Logs the current processing element stats
     */
    void saveStats();

    /**
     * @brief Sends a message to the interconnect.
     *
     * This method sets the source and QoS of the message, performs necessary
     * data processing based on the message type, and enqueues the message
     * into the interconnect.
     *
     * @param msg The message to send.
     * @param interconnect The interconnect to send the message to.
     * @throws std::runtime_error If the address is not aligned to 4 bytes.
     * @throws std::out_of_range If the size or block index is out of range.
     */
    void sendMessage(Message& msg, Interconnect& interconnect);

    /**
     * @brief Receives a message and adds it to the incoming message queue.
     *
     * @param msg The message to receive.
     */
    void receiveMessage(const Message& msg);

    /**
     * @brief Invalidates a cache block in the cache memory.
     *
     * @param cache_line The index of the cache line to invalidate.
     */
    void invalidateCacheBlock(uint8_t cache_line);

    /**
     * @brief Processes a response message.
     *
     * This method handles different types of response messages, such as
     * READ_RESP, WRITE_RESP, and INV_COMPLETE, and performs actions
     * accordingly (e.g., writing to cache, printing status).
     *
     * @param msg The response message to process.
     */
    void processResponse(Message& msg);

    /**
     * @brief Main processing loop for the processing element.
     *
     * This method fetches instructions from the instruction memory, sends them
     * to the interconnect, waits for a response, and processes the response.
     *
     * @param interconnect The interconnect to communicate with.
     */
    void process(Interconnect& interconnect);
};

#endif // PROCESSING_ELEMENT_HPP
