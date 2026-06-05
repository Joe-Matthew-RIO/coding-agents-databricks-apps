#!/usr/bin/env bash
set -euo pipefail

# Claude CLI installer - downloads from DBFS at runtime

HOME="${HOME:-/app/python/source_code}"
BIN_DIR="$HOME/.local/bin"
TARGET_BINARY="$BIN_DIR/claude"
DBFS_BINARY="${CLAUDE_DBFS_PATH:-dbfs:/FileStore/binaries/claude-linux-binary}"

mkdir -p "$BIN_DIR"

echo "Installing Claude CLI from DBFS..."

# Try direct filesystem access first (DBFS is mounted at /dbfs/)
DBFS_MOUNT_PATH="/dbfs/FileStore/binaries/claude-linux-binary"
if [ -f "$DBFS_MOUNT_PATH" ]; then
    cp "$DBFS_MOUNT_PATH" "$TARGET_BINARY"
    chmod +x "$TARGET_BINARY"
    echo "✓ Claude CLI installed successfully from DBFS (direct mount)"
    "$TARGET_BINARY" --version 2>/dev/null || echo "Claude CLI ready"
    exit 0
else
    echo "⚠ DBFS direct mount not found at: $DBFS_MOUNT_PATH"
fi

# Try using databricks CLI as fallback
if command -v databricks >/dev/null 2>&1; then
    # Try without file:// prefix - just use local path
    TEMP_FILE="/tmp/claude-download-$$"
    if databricks fs cp "$DBFS_BINARY" "$TEMP_FILE" 2>/dev/null; then
        mv "$TEMP_FILE" "$TARGET_BINARY"
        chmod +x "$TARGET_BINARY"
        echo "✓ Claude CLI installed successfully from DBFS (via CLI)"
        "$TARGET_BINARY" --version 2>/dev/null || echo "Claude CLI ready"
        exit 0
    else
        echo "⚠ Failed to download from DBFS: $DBFS_BINARY"
        rm -f "$TEMP_FILE"
    fi
else
    echo "⚠ Databricks CLI not available"
fi

# If we get here, installation failed
echo "⚠ Could not install Claude CLI"
echo ""
echo "The Claude binary is too large (234MB) to bundle with the app."
echo "It should be downloaded from DBFS but the download failed."
echo ""
echo "Expected location: $DBFS_BINARY"
echo ""
echo "You can manually install it in this terminal:"
echo ""
echo "  databricks fs cp dbfs:/FileStore/binaries/claude-linux-binary file:///tmp/claude"
echo "  cp /tmp/claude ~/.local/bin/claude"
echo "  chmod +x ~/.local/bin/claude"
echo "  claude --version"

# Create a helpful stub
cat > "$TARGET_BINARY" << 'EOFSTUB'
#!/usr/bin/env bash
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  Claude CLI - Installation Required                           ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "The Claude binary should be downloaded from DBFS."
echo "Run these commands to install it:"
echo ""
echo "  databricks fs cp dbfs:/FileStore/binaries/claude-linux-binary file:///tmp/claude"
echo "  cp /tmp/claude ~/.local/bin/claude && chmod +x ~/.local/bin/claude"
EOFSTUB
chmod +x "$TARGET_BINARY"

exit 0  # Don't fail the setup, just warn
