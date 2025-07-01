#include <algorithm>
#include "processing_element.hpp"

ProcessingElement::ProcessingElement(int16_t w) : weight(w), partial_sum(0) {}

int32_t ProcessingElement::process(int16_t input, int32_t partial_in) {
    int32_t product = static_cast<int32_t>(input) * weight;
    partial_sum = partial_in + product;
    return partial_sum;
}

void ProcessingElement::reset() { 
    partial_sum = 0; 
}

int32_t ProcessingElement::getResult() const { 
    return partial_sum; 
}

int16_t ProcessingElement::getWeight() const { 
    return weight; 
}