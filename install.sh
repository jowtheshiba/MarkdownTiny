#!/bin/bash

set -e

# Check if swift is installed
if ! command -v swift &> /dev/null; then
    echo "Error: Swift is not installed. Please install Swift before running this script."
    exit 1
fi

echo "Swift found. Starting build..."

# Build the project in release mode
swift build -c release

# Find the binary
# We can use swift build --show-bin-path to get the path to the build artifacts directory
BIN_DIR=$(swift build --show-bin-path)
BINARY_NAME="MarkdownTiny"
SOURCE_PATH="$BIN_DIR/$BINARY_NAME"

if [ ! -f "$SOURCE_PATH" ]; then
    echo "Error: Binary $SOURCE_PATH not found after build."
    exit 1
fi

# Determine installation directory (default to /usr/local/bin)
INSTALL_DIR="/usr/local/bin"

echo "Installing $BINARY_NAME to $INSTALL_DIR..."

# Check if we have permission to write to INSTALL_DIR
if [ -w "$INSTALL_DIR" ]; then
    cp "$SOURCE_PATH" "$INSTALL_DIR/$BINARY_NAME"
    chmod +x "$INSTALL_DIR/$BINARY_NAME"
    echo "Successfully installed $BINARY_NAME to $INSTALL_DIR/$BINARY_NAME"
else
    echo "Permission denied: Cannot write to $INSTALL_DIR. Try running with sudo."
    exit 1
fi

echo "You can now run the tool using: markdowntiny"
