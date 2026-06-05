#!/usr/bin/env bash
set -euo pipefail

# Download Linux CLI binaries via WSL for bundling with Databricks Apps
# This script should be run from within WSL (Ubuntu/Debian)
# Usage: bash download-binaries-wsl.sh

echo "════════════════════════════════════════════════════════════════"
echo "  CoDA Binary Downloader for WSL"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "This script downloads Linux CLI binaries that will be bundled"
echo "with the Databricks App deployment."
echo ""

# Determine the Windows project directory from WSL
# Adjust this path if your project is in a different location
WINDOWS_PROJECT_DIR="/mnt/d/JM/git/experiments/source-coda"
BUNDLED_DIR="$WINDOWS_PROJECT_DIR/bundled-binaries"

if [ ! -d "$WINDOWS_PROJECT_DIR" ]; then
    echo "ERROR: Project directory not found: $WINDOWS_PROJECT_DIR"
    echo "Please update WINDOWS_PROJECT_DIR in this script to match your setup."
    exit 1
fi

mkdir -p "$BUNDLED_DIR"

echo "Project directory: $WINDOWS_PROJECT_DIR"
echo "Binaries will be saved to: $BUNDLED_DIR"
echo ""

# Function to download and verify a binary
download_binary() {
    local name=$1
    local installer_url=$2
    local output_file="$BUNDLED_DIR/$name"

    echo "──────────────────────────────────────────────────────────────"
    echo "📦 Downloading $name CLI..."
    echo "──────────────────────────────────────────────────────────────"

    # Create temporary directory for installation
    TEMP_HOME=$(mktemp -d)
    export HOME=$TEMP_HOME
    mkdir -p "$TEMP_HOME/.local/bin"

    # Download and install (use -k to bypass corporate SSL proxy)
    if curl -fsSLk "$installer_url" | bash; then
        local binary_path="$TEMP_HOME/.local/bin/$name"
        if [ -f "$binary_path" ]; then
            cp "$binary_path" "$output_file"
            chmod +x "$output_file"

            # Verify it's a Linux binary
            if file "$output_file" | grep -q "ELF.*x86-64"; then
                local size=$(du -h "$output_file" | cut -f1)
                echo "✓ $name CLI downloaded successfully ($size)"
                file "$output_file"
            else
                echo "⚠ Warning: Binary may not be correct format"
                file "$output_file"
            fi
        else
            echo "⚠ Warning: $name binary not found at expected location"
        fi
    else
        echo "✗ Failed to download $name CLI"
    fi

    # Cleanup temp directory
    rm -rf "$TEMP_HOME"
    echo ""
}

# Download Claude CLI
download_binary "claude" "https://claude.ai/install.sh"

# Add more CLI downloads here as needed in the future
# download_binary "codex" "https://codex.ai/install.sh"
# download_binary "opencode" "https://opencode.ai/install.sh"

echo "════════════════════════════════════════════════════════════════"
echo "  Download Complete!"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "Downloaded binaries:"
ls -lh "$BUNDLED_DIR"
echo ""
echo "Next steps:"
echo "  1. Verify the binaries are correct (should be ELF 64-bit)"
echo "  2. From PowerShell/Git Bash, run:"
echo "     cd $WINDOWS_PROJECT_DIR"
echo "     databricks bundle deploy && databricks bundle run coda"
echo ""
