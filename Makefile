UNAME_S := $(shell uname -s)
UNAME_M := $(shell uname -m)

CC = cc
CXX = c++
CXXFLAGS = -std=c++20 -O2 -DNDEBUG
CFLAGS = -O2
CRYSTAL = crystal

MEDUSA_DIR = ./lib/medusa
QUICKJS_INCLUDE = $(MEDUSA_DIR)/src/ext

ifeq ($(UNAME_S),Darwin)
	ifeq ($(UNAME_M),arm64)
		CXXFLAGS += -I/opt/homebrew/include
	else
		CXXFLAGS += -I/usr/local/include
	endif
endif

BIN_DIR = ./bin
SRC_DIR = ./src
EXT_DIR = ./$(SRC_DIR)/ext

BRIDGE_SRC = $(EXT_DIR)/tachyon_bridge.cpp
BRIDGE_OBJ = $(BIN_DIR)/tachyon_bridge.o
BRIDGE_LIB = $(BIN_DIR)/tachyon_bridge.a

STB_IMAGE_SRC = $(EXT_DIR)/stb_image_impl.c
STB_IMAGE_OBJ = $(BIN_DIR)/stb_image_impl.o

STB_TRUETYPE_SRC = $(EXT_DIR)/stb_truetype_impl.c
STB_TRUETYPE_OBJ = $(BIN_DIR)/stb_truetype_impl.o

MINIAUDIO_SRC = $(EXT_DIR)/miniaudio_impl.c
MINIAUDIO_OBJ = $(BIN_DIR)/miniaudio_impl.o

.PHONY: all bridge stb miniaudio clean run

all: bridge stb miniaudio

bridge: $(BRIDGE_LIB)

$(BRIDGE_LIB): $(BRIDGE_OBJ)
	ar rcs $@ $<

$(BRIDGE_OBJ): $(BRIDGE_SRC)
	@mkdir -p $(BIN_DIR)
	$(CXX) $(CXXFLAGS) -isystem $(QUICKJS_INCLUDE) -c $< -o $@

stb: $(STB_IMAGE_OBJ) $(STB_TRUETYPE_OBJ)

$(STB_IMAGE_OBJ): $(STB_IMAGE_SRC)
	@mkdir -p $(BIN_DIR)
	$(CC) $(CFLAGS) -I$(EXT_DIR) -c $< -o $@

$(STB_TRUETYPE_OBJ): $(STB_TRUETYPE_SRC)
	@mkdir -p $(BIN_DIR)
	$(CC) $(CFLAGS) -I$(EXT_DIR) -c $< -o $@

miniaudio: $(MINIAUDIO_OBJ)

$(MINIAUDIO_OBJ): $(MINIAUDIO_SRC) $(EXT_DIR)/miniaudio.h
	@mkdir -p $(BIN_DIR)
	$(CC) $(CFLAGS) -c $< -o $@

clean:
	rm -rf $(BIN_DIR)/*