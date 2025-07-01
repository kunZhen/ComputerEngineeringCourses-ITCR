#include <iostream>
#include "logger.hpp"

std::string Logger::get_current_timestamp() {
    auto now = std::chrono::system_clock::now();
    auto in_time_t = std::chrono::system_clock::to_time_t(now);
    
    std::stringstream ss;
    ss << std::put_time(std::localtime(&in_time_t), "%Y-%m-%d %X");
    return ss.str();
}

Logger::Logger(const std::string& filename, bool console_output)
    : filename(filename), console_output(console_output) {
    if (!filename.empty()) {
        log_file.open(filename, std::ios::out | std::ios::trunc);
        if (!log_file.is_open()) {
            throw std::runtime_error("Failed to open log file");
        }
    }
}

Logger::~Logger() {
    if (log_file.is_open()) {
        log_file.close();
    }
}

void Logger::log(const std::string& message, const std::string& source) {
    std::lock_guard<std::mutex> lock(log_mutex);
    std::string timestamp = get_current_timestamp();
    std::string log_entry;

    if (!source.empty()) {
        log_entry = "\n[" + timestamp + "] [" + source + "] " + message;
    } else {
        log_entry = "\n[" + timestamp + "] " + message;
    }

    if (console_output) {
        std::cout << log_entry << std::endl;
    }

    if (log_file.is_open()) {
        log_file << log_entry << std::endl;
    }
}
