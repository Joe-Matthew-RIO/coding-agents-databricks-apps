# Binary Update Instructions

This guide explains how to download and bundle Linux CLI binaries for the CoDA Databricks App.

## Why This is Needed

The CoDA app runs in a Linux container on Databricks Apps. In enterprise environments with network restrictions, the app cannot download CLI binaries at runtime. Instead, we pre-download the Linux binaries and bundle them with the deployment.

## Prerequisites

- **Windows Subsystem for Linux (WSL)** installed with Ubuntu
- **Internet access** from WSL (may work even if Windows has restrictions)
- The CoDA project cloned to your Windows machine

## Step-by-Step Instructions

### 1. Open WSL (Ubuntu)

From PowerShell or Windows Terminal:

```powershell
wsl
```

Or search for "Ubuntu" in the Start menu.

### 2. Navigate to the project directory

In WSL, navigate to your Windows project directory:

```bash
cd /mnt/d/JM/git/experiments/source-coda
```

**Note:** Windows drives are mounted at `/mnt/` in WSL:
- `C:\` → `/mnt/c/`
- `D:\` → `/mnt/d/`
- Adjust the path based on where your project is located

### 3. Run the download script

```bash
bash download-binaries-wsl.sh
```

This will:
- Download the Claude CLI Linux binary
- Save it to `bundled-binaries/claude`
- Verify it's the correct format (ELF 64-bit Linux executable)
- Show the file size and details

### 4. Verify the download

Still in WSL:

```bash
ls -lh bundled-binaries/
file bundled-binaries/claude
```

Expected output:
```
bundled-binaries/claude: ELF 64-bit LSB executable, x86-64
```

The file should be approximately 200-300 MB.

### 5. Deploy to Databricks

Exit WSL and return to PowerShell/Git Bash:

```bash
exit  # Exit WSL
```

Then deploy:

```bash
cd D:\JM\git\experiments\source-coda
databricks bundle deploy && databricks bundle run coda
```

## Troubleshooting

### WSL can't reach the internet

If WSL also has network restrictions, you'll need to:

1. Download binaries from a personal device (home computer, laptop with mobile hotspot)
2. Transfer via USB drive or personal email
3. Copy to `bundled-binaries/` directory

### Binary is wrong architecture

If you accidentally get a non-Linux binary:

```bash
# Check what you have
file bundled-binaries/claude

# Should say "ELF 64-bit LSB executable, x86-64"
# NOT "PE32" (Windows) or "Mach-O" (Mac)
```

### Download script fails

If the installer URL changes, update the script:

1. Edit `download-binaries-wsl.sh`
2. Update the `installer_url` for the failing CLI
3. Re-run the script

## Adding New CLIs

To download additional CLI tools (codex, opencode, gemini, etc.), edit `download-binaries-wsl.sh` and add:

```bash
# Add at the end, before the "Download Complete" section
download_binary "codex" "https://codex.ai/install.sh"
download_binary "opencode" "https://opencode.ai/install.sh"
```

## Updating Existing Binaries

To update to the latest version:

1. Delete old binaries:
   ```bash
   rm bundled-binaries/claude
   ```

2. Re-run the download script:
   ```bash
   wsl
   cd /mnt/d/JM/git/experiments/source-coda
   bash download-binaries-wsl.sh
   exit
   ```

3. Redeploy:
   ```bash
   databricks bundle deploy && databricks bundle run coda
   ```

## Quick Reference

| Task | Command |
|------|---------|
| Open WSL | `wsl` |
| Navigate to project | `cd /mnt/d/JM/git/experiments/source-coda` |
| Download binaries | `bash download-binaries-wsl.sh` |
| Check binary | `file bundled-binaries/claude` |
| Exit WSL | `exit` |
| Deploy app | `databricks bundle deploy && databricks bundle run coda` |

## Alternative: Manual Download (Without WSL)

If WSL isn't available:

1. **From a Linux/Mac machine** (or WSL on another computer):
   ```bash
   curl -fsSL https://claude.ai/install.sh | bash
   cp ~/.local/bin/claude ~/claude-linux
   ```

2. **Transfer the file** to your work machine (USB, personal email)

3. **Copy to project**:
   ```bash
   cp ~/Downloads/claude-linux D:/JM/git/experiments/source-coda/bundled-binaries/claude
   chmod +x D:/JM/git/experiments/source-coda/bundled-binaries/claude
   ```

4. **Deploy**:
   ```bash
   databricks bundle deploy && databricks bundle run coda
   ```

## Files Reference

- `download-binaries-wsl.sh` - The download script (run from WSL)
- `bundled-binaries/` - Directory containing pre-downloaded binaries
- `bundled-binaries/README.md` - Quick reference
- `install_claude_offline.sh` - Installer script (runs during app startup)

## Support

If you encounter issues:
1. Check that WSL can access the internet: `curl -I https://claude.ai`
2. Verify the project path is correct in the script
3. Ensure you have write permissions to the project directory
4. Check the binary format with `file bundled-binaries/claude`
