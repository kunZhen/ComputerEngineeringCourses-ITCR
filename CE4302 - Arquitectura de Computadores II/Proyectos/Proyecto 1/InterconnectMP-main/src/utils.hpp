#ifndef UTILS_HPP
#define UTILS_HPP

#include <iostream>
#include <iomanip>
#include <fstream>
#include "message.hpp"

/**
 * @brief Prints the details of a Message struct.
 *
 * @param msg The Message object to print.
 */
void printMessage(const Message& msg);

/**
 * @brief Return the incoming/outgoing message
 *
 * @param begin How to start the log message.
 * @param msg The message to log.
 */
std::string messageToLog(const std::string& begin, const Message& msg);

/**
 * @brief Calculates the total size of a Message struct.
 *
 * @param msg The total size of the struct.
 */
size_t calculateMessageSize(const Message& msg);

/**
 * @brief Loads qos values from a file.
 *
 * @param filename Path to file containing qos data.
 */
std::vector<uint8_t> loadQoS(const std::string& filename);

#endif // UTILS_HPP
