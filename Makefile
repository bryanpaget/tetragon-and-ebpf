# Makefile for generating Marp PDF presentations

# Variables
HEADER_MD = config/header.md
TEMP_DIR = temp
IMG_DIR = img
MARP_OPTS = --allow-local-files --pdf-outlines

# English presentation
INPUT_MD_EN = content/slides-en.md
COMBINED_MD_EN = $(TEMP_DIR)/slides-en-combined.md
OUTPUT_PDF_EN = tetragon-ebpf-presentation-en.pdf

# French presentation
INPUT_MD_FR = content/slides-fr.md
COMBINED_MD_FR = $(TEMP_DIR)/slides-fr-combined.md
OUTPUT_PDF_FR = tetragon-ebpf-presentation-fr.pdf

# Default target
all: pdf

# Create both PDFs
pdf: setup combine-en combine-fr
	@echo "Building English PDF..."
	marp $(MARP_OPTS) --pdf --output $(OUTPUT_PDF_EN) $(COMBINED_MD_EN)
	@echo "Building French PDF..."
	marp $(MARP_OPTS) --pdf --output $(OUTPUT_PDF_FR) $(COMBINED_MD_FR)
	@echo "PDFs built: $(OUTPUT_PDF_EN), $(OUTPUT_PDF_FR)"

# Build English only
pdf-en: setup combine-en
	@echo "Building English PDF..."
	marp $(MARP_OPTS) --pdf --output $(OUTPUT_PDF_EN) $(COMBINED_MD_EN)
	@echo "PDF built: $(OUTPUT_PDF_EN)"

# Build French only
pdf-fr: setup combine-fr
	@echo "Building French PDF..."
	marp $(MARP_OPTS) --pdf --output $(OUTPUT_PDF_FR) $(COMBINED_MD_FR)
	@echo "PDF built: $(OUTPUT_PDF_FR)"

# Setup temporary directory and copy assets
setup:
	@echo "Setting up temporary directory..."
	mkdir -p $(TEMP_DIR)
	cp -r $(IMG_DIR) $(TEMP_DIR)/

# Combine header and English content
combine-en: setup
	@echo "Combining header and English content..."
	cat $(HEADER_MD) $(INPUT_MD_EN) > $(COMBINED_MD_EN)

# Combine header and French content
combine-fr: setup
	@echo "Combining header and French content..."
	cat $(HEADER_MD) $(INPUT_MD_FR) > $(COMBINED_MD_FR)

# Clean up generated files
clean:
	@echo "Cleaning up..."
	rm -rf $(TEMP_DIR)
	rm -f $(OUTPUT_PDF_EN) $(OUTPUT_PDF_FR)

# Install Marp CLI and Chromium
deps:
	@echo "Installing Marp CLI and Chromium..."
	npm install -g @marp-team/marp-cli
	sudo apt-get update && sudo apt-get install -y chromium-browser

# Install Chromium only (if Marp already installed)
install-chromium:
	@echo "Installing Chromium..."
	sudo apt-get update && sudo apt-get install -y chromium-browser

# Check if Marp is installed
check-marp:
	@which marp || (echo "Marp CLI not installed. Run 'make deps' first." && exit 1)

# Preview the English presentation in browser
preview-en: setup combine-en check-marp
	@echo "Starting preview server for English presentation..."
	marp $(COMBINED_MD_EN) --server --allow-local-files --port 8080

# Preview the French presentation in browser
preview-fr: setup combine-fr check-marp
	@echo "Starting preview server for French presentation..."
	marp $(COMBINED_MD_FR) --server --allow-local-files --port 8081

# Build and open PDFs
open: pdf
	@if command -v xdg-open > /dev/null; then \
		xdg-open $(OUTPUT_PDF_EN); \
		xdg-open $(OUTPUT_PDF_FR); \
	elif command -v open > /dev/null; then \
		open $(OUTPUT_PDF_EN); \
		open $(OUTPUT_PDF_FR); \
	else \
		echo "Cannot open PDFs automatically. Please open $(OUTPUT_PDF_EN) and $(OUTPUT_PDF_FR) manually."; \
	fi

# Help target
help:
	@echo "Available targets:"
	@echo "  all            - Build both PDFs (default)"
	@echo "  pdf            - Build both PDFs"
	@echo "  pdf-en         - Build English PDF only"
	@echo "  pdf-fr         - Build French PDF only"
	@echo "  preview-en     - Start live preview server for English (port 8080)"
	@echo "  preview-fr     - Start live preview server for French (port 8081)"
	@echo "  open           - Build both PDFs and open them"
	@echo "  deps           - Install Marp CLI and Chromium"
	@echo "  install-chromium - Install Chromium only"
	@echo "  clean          - Remove generated files"
	@echo "  help           - Show this help message"

.PHONY: all pdf pdf-en pdf-fr setup combine-en combine-fr clean deps install-chromium preview-en preview-fr open help check-marp
