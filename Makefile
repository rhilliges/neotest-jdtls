SRC_DIR=lua
TESTS_DIR=tests
TEST_CONFIG=${TESTS_DIR}/minimal_init.lua

.PHONY: test lint format all

all: lint format test

test:
	nvim --headless -c "PlenaryBustedDirectory ${TESTS_DIR} {minimal_init = '${TEST_CONFIG}'}"
lint: 
	luacheck ${SRC_DIR} ${TESTS_DIR}

format:
	stylua ${SRC_DIR}  ${TESTS_DIR} --config-path=.stylua.toml
