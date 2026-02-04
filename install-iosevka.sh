#!/bin/bash
set -e  # Exit on any error

# Install Iosevka font to user fonts directory (no sudo required)

# Check if running on Linux
if [[ "$(uname -s)" != "Linux" ]]; then
    echo "Error: This script only runs on Linux."
    exit 1
fi

RELEASE="33.2.1"
FONT_DIR="$HOME/.local/share/fonts/iosevka"

# Skip if already installed
if [ -d "$FONT_DIR" ] && [ "$(ls -A $FONT_DIR 2>/dev/null)" ]; then
    echo "Iosevka font already installed, skipping."
    exit 0
fi

echo "Installing Iosevka font v${RELEASE}..."

# Create temp directory
TMP_DIR=$(mktemp -d)
cd "$TMP_DIR"

# Download and extract
wget -q "https://github.com/be5invis/Iosevka/releases/download/v${RELEASE}/SuperTTC-Iosevka-${RELEASE}.zip" -O iosevka.zip
if [ $? -ne 0 ]; then
    echo "Failed to download Iosevka font"
    rm -rf "$TMP_DIR"
    exit 1
fi

unzip -q iosevka.zip

# Install to user fonts
mkdir -p "$FONT_DIR"
mv *.ttc "$FONT_DIR/" 2>/dev/null || mv *.ttf "$FONT_DIR/" 2>/dev/null

# Cleanup
rm -rf "$TMP_DIR"

# Refresh font cache
fc-cache -f "$FONT_DIR"

echo "Iosevka font installed successfully."
