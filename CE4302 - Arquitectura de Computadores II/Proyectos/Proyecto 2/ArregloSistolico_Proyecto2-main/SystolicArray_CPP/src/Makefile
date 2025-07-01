CXX = g++
CXXFLAGS = -g -Wall -Wextra
SRC = main.cpp main_memory.cpp image_processor.cpp processing_element.cpp systolic_array.cpp
OBJ = $(SRC:.cpp=.o)
TARGET = main

all: $(TARGET)

$(TARGET): $(OBJ)
	$(CXX) $(CXXFLAGS) -o $@ $^

%.o: %.cpp
	$(CXX) $(CXXFLAGS) -c $<

clean:
	rm -f $(OBJ) $(TARGET)