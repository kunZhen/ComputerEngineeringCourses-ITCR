#ifndef INTERCONNECT_HPP
#define INTERCONNECT_HPP

#include <vector>
#include <queue>
#include <mutex>
#include <atomic>
#include <thread>
#include <unistd.h>
#include <condition_variable>
#include "logger.hpp"
#include "message.hpp"
#include "shared_memory.hpp"

// Forward declaration
class ProcessingElement;

/**
 * @brief Structure to save stats of the interconnect
 */
struct InterconnectStats {
    // Basic counters
    size_t total_messages_processed = 0;
    size_t read_operations = 0;
    size_t write_operations = 0;
    size_t invalidations = 0;

    // Processing times
    std::vector<double> processing_times;
    std::chrono::microseconds total_processing_time{0};
    std::chrono::time_point<std::chrono::high_resolution_clock> last_processing_start;

    // Queue statistics
    size_t max_qsize = 0;
    size_t total_qobservations = 0;
    double avg_qsize = 0;

    // Utility methods
    void startProcessing() {
        last_processing_start = std::chrono::high_resolution_clock::now();
    }

    void endProcessing(size_t current_qsize) {
        auto end = std::chrono::high_resolution_clock::now();
        auto duration = std::chrono::duration_cast<std::chrono::microseconds>(
            end - last_processing_start);
        
        processing_times.push_back(duration.count());
        total_processing_time += duration;

        max_qsize = std::max(max_qsize, current_qsize);
        avg_qsize = (avg_qsize * total_qobservations + current_qsize) / 
                   (total_qobservations + 1);
        total_qobservations++;
    }

    std::string getSummary(std::string& arbitration) const {
        std::stringstream ss;
        ss << std::fixed << std::setprecision(2);
        
        double avg_process_time = processing_times.empty() ? 0.0 :
            std::accumulate(processing_times.begin(), processing_times.end(), 0.0) 
            / processing_times.size();

        ss << "\n======== Interconnect Stats ========\n"
           << "Arbitration:         " << arbitration << "\n\n"
           << "Total Messages:      " << total_messages_processed << "\n"
           << "  READ_MEM:          " << read_operations << "\n"
           << "  WRITE_MEM:         " << write_operations << "\n"
           << "  INVALIDATIONS:     " << invalidations << "\n\n"
           << "Processing Times (μs):\n"
           << "  Average:           " << avg_process_time << "\n"
           << "  Total:             " << total_processing_time.count() << "\n\n"
           << "Queue Statistics:\n"
           << "  Max Size:          " << max_qsize << "\n"
           << "  Average Size:      " << avg_qsize << "\n"
           << "====================================\n";

        return ss.str();
    }
};

/**
 * @brief Comparator for prioritizing messages based on QoS.
 *
 * Ensures that messages with higher QoS values are processed first.
 */
struct QoSComparator {
    /**
     * @brief Compares two messages based on their QoS values.
     *
     * @param a The first message.
     * @param b The second message.
     * @return True if the QoS of message `a` is less than that of message `b`.
     */
    bool operator()(const Message& a, const Message& b) {
        return a.qos < b.qos; // Higher QoS is prioritized
    }
};

/**
 * @brief Class representing the interconnect in a multi-core system.
 *
 * Handles communication between processing elements (PEs) and shared memory,
 * supporting FIFO and QoS-based arbitration schemes.
 */
class Interconnect {
private:
    std::vector<ProcessingElement*> pes; // List of registered processing elements
    SharedMemory& memory;                // Reference to shared memory
    std::queue<Message> fifo_queue;      // FIFO queue for messages
    std::priority_queue<Message, std::vector<Message>, QoSComparator> qos_queue; // qos queue for messages
    std::mutex queue_mutex;              // Mutex for thread-safe access to queues
    bool use_qos_arbitration = false;    // Flag to determine arbitration scheme
    bool stepping_mode = false;          // Flag to enable stepping mode
    std::atomic<bool> running;           // Flag to process messages
    InterconnectStats stats;             // Stats of the Interconnect

public:
    /**
     * @brief Constructor for the Interconnect class.
     *
     * @param mem Reference to shared memory.
     * @param use_qos Flag indicating whether to use QoS-based arbitration.
     */
    Interconnect(SharedMemory& mem, bool use_qos);

    /**
     * @brief Gets the InterconnectStats struct of the interconnect.
     *
     * @return The InterconnectStats struct of the interconnect.
     */
    const InterconnectStats& getStats();

    /**
     * @brief Registers a processing element (PE) with the interconnect.
     *
     * @param pe Pointer to the processing element to register.
     */
    void registerPE(ProcessingElement* pe);

    /**
     * @brief Sets the arbitration scheme for message processing.
     *
     * @param use_qos Flag indicating whether to use QoS-based arbitration.
     */
    void setArbitrationScheme(bool use_qos);

    /**
     * @brief Sets the stepping mode for message processing.
     *
     * @param enable True to enable step-by-step processing, false for continuous.
     */
    void setSteppingMode(bool enable);

    /**
     * @brief Enqueues a message into the appropriate queue based on the arbitration scheme.
     *
     * @param msg The message to enqueue.
     */
    void enqueueMessage(const Message& msg);

    /**
     * @brief Sets the running flag to false to stop processing messages.
     */
    void stopProcessing();

    /**
     * @brief Processes messages from the queue and performs actions based on their types.
     *
     * This method continuously processes messages, reading from shared memory,
     * writing to shared memory, or broadcasting cache invalidations as needed.
     */
    void processMessages();
};

#endif // INTERCONNECT_HPP
