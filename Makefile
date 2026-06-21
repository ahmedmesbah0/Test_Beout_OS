.PHONY: all iso src clean help

BUILD_SCRIPT := ./build.sh

all:
	@echo "==== BeoutOS - Full Build ===="
	@bash $(BUILD_SCRIPT) all

iso:
	@echo "==== BeoutOS - ISO Build ===="
	@bash $(BUILD_SCRIPT) iso

src:
	@echo "==== BeoutOS - Source Build ===="
	@bash $(BUILD_SCRIPT) src

clean:
	@echo "==== BeoutOS - Clean ===="
	@bash $(BUILD_SCRIPT) clean

help:
	@bash $(BUILD_SCRIPT) help
