CXX = g++
CXXFLAGS = -g -Wall -Wextra
SRC = main.cpp interconnect.cpp processing_element.cpp shared_memory.cpp cache_memory.cpp instruction_memory.cpp utils.cpp logger.cpp
OBJ = $(SRC:.cpp=.o)
TARGET = simulator

all: $(TARGET)

$(TARGET): $(OBJ)
	$(CXX) $(CXXFLAGS) -o $@ $^

%.o: %.cpp
	$(CXX) $(CXXFLAGS) -c $<

clean:
	rm -f $(OBJ) $(TARGET)