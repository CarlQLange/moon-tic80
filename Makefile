# TIC-80 LiveScript Development Makefile
# Compiles LiveScript to JavaScript for TIC-80

# Project configuration
PROJECT_NAME := moon
MAIN_LS := src/$(PROJECT_NAME).ls
COMPILED_JS := $(PROJECT_NAME).js

# LiveScript and TIC-80 commands
LSC := lsc
TIC80 := tic80
TIC80_FLAGS := --fs .

# File watching command (prefer fswatch on macOS, fallback to entr)
WATCHER := $(shell which fswatch 2>/dev/null || which entr 2>/dev/null)

.PHONY: compile dev run build web clean help

# Default target
help:
	@echo "TIC-80 LiveScript Development Commands:"
	@echo "  make compile - Compile LiveScript to JavaScript"
	@echo "  make dev     - Watch src/ and auto-reload on changes"
	@echo "  make run     - Compile and run once"
	@echo "  make build   - Build $(PROJECT_NAME).tic"
	@echo "  make web     - Export $(PROJECT_NAME) for web"
	@echo "  make clean   - Clean generated files"
	@echo ""
	@echo "LiveScript files: src/*.ls -> $(COMPILED_JS)"

# Compile LiveScript to JavaScript
compile:
	@if [ ! -f "$(MAIN_LS)" ]; then \
		echo "Error: $(MAIN_LS) not found"; \
		exit 1; \
	fi
	@if ! command -v $(LSC) >/dev/null 2>&1; then \
		echo "Error: LiveScript not found. Install with: npm install -g livescript"; \
		exit 1; \
	fi
	@echo "Compiling LiveScript files..."
	$(LSC) --compile --bare --no-header --output . $(MAIN_LS)
	@echo "// title:   Moon" > $(COMPILED_JS).tmp
	@echo "// author:  Carl Lange" >> $(COMPILED_JS).tmp
	@echo "// desc:    A space adventure on the moon" >> $(COMPILED_JS).tmp
	@echo "// site:" >> $(COMPILED_JS).tmp
	@echo "// license: MIT License" >> $(COMPILED_JS).tmp
	@echo "// version: 0.1" >> $(COMPILED_JS).tmp
	@echo "// script:  js" >> $(COMPILED_JS).tmp
	@echo "" >> $(COMPILED_JS).tmp
	@cat $(PROJECT_NAME).js >> $(COMPILED_JS).tmp
	@mv $(COMPILED_JS).tmp $(COMPILED_JS)
	@echo "Compiled to $(COMPILED_JS)"

# Development with file watching
dev: compile
	@if [ -z "$(WATCHER)" ]; then \
		echo "Error: Neither fswatch nor entr found. Please install one:"; \
		echo "  brew install fswatch"; \
		echo "  brew install entr"; \
		exit 1; \
	fi
	@echo "Watching src/ for changes. Press Ctrl+C to stop."
	@if command -v fswatch >/dev/null 2>&1; then \
		fswatch -o src/ | while read; do \
			echo "LiveScript files changed, recompiling..."; \
			make compile && $(TIC80) $(TIC80_FLAGS) --cmd "new js & import code $(COMPILED_JS) & run"; \
		done; \
	else \
		find src -name "*.ls" | entr -r sh -c 'make compile && $(TIC80) $(TIC80_FLAGS) --cmd "new js & import code $(COMPILED_JS) & run"'; \
	fi

# Single run
run: compile
	$(TIC80) $(TIC80_FLAGS) --cmd "new js & import code $(COMPILED_JS) & run"

# Build .tic file
build: compile
	$(TIC80) $(TIC80_FLAGS) --cmd "new js & import code $(COMPILED_JS) & save $(PROJECT_NAME).tic"
	@echo "Built $(PROJECT_NAME).tic"

# Export for web
web: build
	$(TIC80) $(TIC80_FLAGS) --cmd "load $(PROJECT_NAME).tic & export html $(PROJECT_NAME)"
	@echo "Exported $(PROJECT_NAME) for web"

# Clean generated files
clean:
	@echo "Cleaning generated files..."
	@rm -f *.tic
	@rm -f *.html
	@rm -f *.js
	@rm -f *.wasm
	@rm -f *.zip
	@rm -f cart.tic
	@echo "Clean complete"