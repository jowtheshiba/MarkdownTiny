#!/bin/bash

set -e

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
# We use the current script's URL if possible, but here we'll use a reliable source
# Since this is for your repo:
REPO_URL="https://github.com/jowtheshiba/MarkdownTiny.git"
git clone "$REPO_URL" "$TEMP_DIR"

cd "$TEMP_DIR"

echo "Starting build..."

# Build the project in release mode
swift build -c release

# Find the binary
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
