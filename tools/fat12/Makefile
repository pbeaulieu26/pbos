CC = g++
CFLAGS = -Wall -g -std=c++11 

BUILD_DIR = build
SRC_DIR = src

.PHONY: all fat12 always clean

# 
# fat12
#
fat12 : $(BUILD_DIR)/fat12

$(BUILD_DIR)/fat12 : $(BUILD_DIR)/main.o
	$(CC) $(CFLAGS) -o $(BUILD_DIR)/fat12 $(BUILD_DIR)/main.o

$(BUILD_DIR)/main.o: always
	$(CC) $(CFLAGS) -c $(SRC_DIR)/main.cpp -o $(BUILD_DIR)/main.o

#
# Always
#
always:
	mkdir -p $(BUILD_DIR)

#
# clean
#
clean:
	rm -rf $(BUILD_DIR)