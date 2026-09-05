#!/bin/bash

set -e

echo "--- MarkdownTiny Installer v3 ---"

# Check if swift is installed
if ! command -v swift &> /dev/null; then
    echo "Error: Swift is not installed. Please install Swift before running this script."
    exit 1
fi

# Create a temporary directory for cloning and building
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

echo "Swift found. Cloning repository into $TEMP_DIR..."

# Clone the repository
REPO_URL="https://github.com/jowtheshiba/MarkdownTiny.git"
git clone "$REPO_URL" "$TEMP_DIR"

cd "$TEMP_DIR"

echo "Starting build in release mode..."

# Build the project in release mode
swift build -c release

echo "Build complete!"

# Find the binary precisely using find, looking for the executable named MarkdownTiny
# This handles both debug and release folders on different platforms
SOURCE_PATH=$(find "$TEMP_DIR/.build" -name "MarkdownTiny" -type f | head -n 1)

if [ -z "$SOURCE_PATH" ]; then
    echo "Error: Could not find the MarkdownTiny binary in $TEMP_DIR/.build"
    exit 1
fi

echo "Found binary at: $SOURCE_PATH"

# Determine installation directory (default to /usr/local/bin)
INSTALL_DIR="/usr/local/bin"

echo "Installing MarkdownTiny to $INSTALL_DIR..."

# Check if we have permission to write to INSTALL_DIR
if [ -w "$INSTALL_DIR" ]; then
    cp "$SOURCE_PATH" "$INSTALL_DIR/markdowntiny"
    chmod +x "$INSTALL_DIR/markdowntiny"
    echo "Successfully installed markdowntiny to $INSTALL_DIR/markdowntiny"
else
    echo "Permission denied: Cannot write to $INSTALL_DIR. Try running with sudo."
    exit 1
fi

echo "You can now run the tool using: markdowntiny"
