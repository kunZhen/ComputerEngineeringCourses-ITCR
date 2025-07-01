#ifndef PROCESSING_ELEMENT_HPP
#define PROCESSING_ELEMENT_HPP

#include <cstdint>

/**
 * @class ProcessingElement
 * @brief Represents a single processing element in a systolic array
 * 
 * This class handles the core multiply-accumulate (MAC) operations and 
 * includes functionality for weight storage, partial sum calculation, 
 * and value clamping.
 */
class ProcessingElement {
private:
    int16_t weight;        // Weight value stored in the PE (16-bit signed)
    int32_t partial_sum;   // Current partial sum (32-bit signed)

public:
    /**
     * @brief Constructor for ProcessingElement
     * @param w Initial weight value (default 0)
     */
    ProcessingElement(int16_t w = 0);

    /**
     * @brief Process input data with multiply-accumulate operation
     * @param input Input data value (16-bit signed)
     * @param partial_in Partial sum from previous PE (32-bit signed)
     * @return Result of MAC operation clamped to [-128, 127] range
     */
    int32_t process(int16_t input, int32_t partial_in);

    /**
     * @brief Reset the partial sum to zero
     */
    void reset();

    /**
     * @brief Get the current result (partial sum)
     * @return Current partial sum value
     */
    int32_t getResult() const;

    /**
     * @brief Get the current weight value
     * @return Current weight value
     */
    int16_t getWeight() const;
};

#endif // PROCESSING_ELEMENT_HPP