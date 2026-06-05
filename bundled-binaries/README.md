# Bundled Binaries

Pre-downloaded Linux CLI binaries for the CoDA Databricks App.

## Quick Start (For Future Updates)

### Using WSL (Recommended)

```bash
# 1. Open WSL
wsl

# 2. Navigate to project
cd /mnt/d/JM/git/experiments/source-coda

# 3. Download binaries
bash download-binaries-wsl.sh

# 4. Exit WSL and deploy
exit
databricks bundle deploy && databricks bundle run coda
```

### Manual Download (Alternative)

If WSL isn't available, download from a machine with internet access:

```bash
# On Linux/Mac/WSL (at home or on personal device)
curl -fsSL https://claude.ai/install.sh | bash
cp ~/.local/bin/claude ~/claude-linux

# Transfer to work machine, then:
cp ~/Downloads/claude-linux D:/JM/git/experiments/source-coda/bundled-binaries/claude
chmod +x bundled-binaries/claude
```

## What Goes Here

This directory contains pre-downloaded Linux (ELF x86-64) binaries for:

- `claude` - Claude Code CLI (~200-300 MB)
- Additional CLIs can be added in the future (codex, opencode, etc.)

## Why?

The Databricks App runs in a restricted Linux container that cannot download binaries at runtime due to enterprise network restrictions. Pre-bundling ensures the CLIs are available immediately when the app starts.

## Verification

Check that binaries are correct format:

```bash
file claude
# Expected: claude: ELF 64-bit LSB executable, x86-64

ls -lh
# Expected: ~200-300 MB for claude binary
```

## See Also

- `../BINARY-UPDATE-INSTRUCTIONS.md` - Detailed update guide
- `../download-binaries-wsl.sh` - Automated download script
- `../install_claude_offline.sh` - Runtime installer (used by app)
