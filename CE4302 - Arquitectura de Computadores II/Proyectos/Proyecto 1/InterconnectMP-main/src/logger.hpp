#ifndef LOGGER_HPP
#define LOGGER_HPP

#include <fstream>
#include <mutex>
#include <string>
#include <iomanip>
#include <chrono>
#include <sstream>

/**
 * @brief A simple logger class that supports logging to a file and/or console.
 *
 * This class provides a way to log messages with timestamps and optional sources,
 * and can output logs to both a file and the console.
 */
class Logger {
private:
    std::ofstream log_file;     // Output stream for the log file
    std::mutex log_mutex;       // Mutex to ensure thread-safe logging
    std::string filename;       // Name of the log file
    bool console_output;        // Flag to enable/disable console output

    /**
     * @brief Internal function to format the current timestamp.
     *
     * @return A string representing the current timestamp in the format "YYYY-MM-DD HH:MM:SS".
     */
    std::string get_current_timestamp();

public:
    /**
     * @brief Logger class constructor.
     *
     * @param filename       The name of the log file (optional). If empty, logging to file is disabled.
     * @param console_output Flag to enable/disable console output (default: true).
     *
     * @throws std::runtime_error if the log file cannot be opened.
     */
    explicit Logger(const std::string& filename = "", bool console_output = true);

    /**
     * @brief Logger class destructor.
     *
     * Closes the log file if it is open.
     */
    ~Logger();

    /**
     * @brief Writes a message to the log.
     *
     * @param message The message to write.
     * @param source  The source of the message (optional).
     */
    void log(const std::string& message, const std::string& source = "");

    // Disable copy constructor and assignment operator
    Logger(const Logger&) = delete;
    Logger& operator=(const Logger&) = delete;
};

#endif // LOGGER_HPP
