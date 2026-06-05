# Claude CLI Binary Deployment Guide

This document explains how Claude CLI binaries are deployed and loaded in the CoDA Databricks App environment.

## Table of Contents

- [Overview](#overview)
- [Why This Approach](#why-this-approach)
- [Architecture](#architecture)
- [How It Works](#how-it-works)
- [Updating the Claude Binary](#updating-the-claude-binary)
- [Troubleshooting](#troubleshooting)
- [Alternative Approaches Tried](#alternative-approaches-tried)

---

## Overview

The Claude CLI binary (~234 MB) is too large to bundle directly with the Databricks App deployment. Instead, it's stored in **DBFS (Databricks File System)** and automatically copied to the app container during initialization.

**Key Components:**
- **Storage Location**: `dbfs:/FileStore/binaries/claude-linux-binary`
- **Mount Point**: `/dbfs/FileStore/binaries/claude-linux-binary` (accessible from app container)
- **Installation Script**: `install_claude_offline.sh`
- **Target Location**: `~/.local/bin/claude` (in user's PATH)

---

## Why This Approach

### The Challenge

1. **File Size Limits**: Databricks Apps has a 50 MB limit for files in the deployment package
2. **Claude Binary Size**: The Linux x86-64 Claude CLI binary is ~234 MB
3. **Network Restrictions**: Corporate firewalls block direct downloads from claude.ai
4. **Volume Access**: Unity Catalog Volumes are not accessible from Databricks Apps containers

### The Solution

Store the binary in **DBFS FileStore**, which:
- ✅ Supports large files (no size limit)
- ✅ Is accessible from app containers via `/dbfs/` mount
- ✅ Persists across app restarts
- ✅ Can be updated independently of app deployments
- ✅ Doesn't require special permissions

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     CoDA App Startup                         │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
                 ┌────────────────────────┐
                 │   gunicorn.conf.py     │
                 │  post_worker_init()    │
                 └────────────────────────┘
                              │
                              ▼
                 ┌────────────────────────┐
                 │   initialize_app()     │
                 │   (background thread)  │
                 └────────────────────────┘
                              │
                              ▼
         ┌───────────────────────────────────────┐
         │  Parallel Setup Steps:                │
         │  - git config                         │
         │  - micro editor                       │
         │  - GitHub CLI                         │
         │  - Databricks CLI                     │
         │  ➜ Claude CLI (install_claude_offline.sh) │
         │  - MLflow tracing                     │
         └───────────────────────────────────────┘
                              │
                              ▼
         ┌───────────────────────────────────────┐
         │  install_claude_offline.sh            │
         │                                       │
         │  1. Check /dbfs/ mount point         │
         │  2. Copy binary from DBFS            │
         │  3. Make executable                   │
         │  4. Verify installation              │
         └───────────────────────────────────────┘
                              │
                              ▼
              ┌──────────────────────────┐
              │  ~/.local/bin/claude     │
              │  (Ready to use)          │
              └──────────────────────────┘
```

---

## How It Works

### 1. Binary Storage (One-Time Setup)

The Claude Linux binary is uploaded to DBFS FileStore:

```bash
# Upload binary to DBFS (run from local machine)
databricks fs cp /path/to/claude-linux-binary dbfs:/FileStore/binaries/claude-linux-binary --overwrite
```

**Location**: `dbfs:/FileStore/binaries/claude-linux-binary`

### 2. App Configuration

The DBFS path is configured as an environment variable in `databricks.yml`:

```yaml
env:
  - name: CLAUDE_DBFS_PATH
    value: "dbfs:/FileStore/binaries/claude-linux-binary"
```

### 3. Runtime Installation

During app initialization, `install_claude_offline.sh` runs:

#### Step 3a: Direct Mount Access (Primary Method)

```bash
# DBFS is mounted at /dbfs/ in Databricks containers
DBFS_MOUNT_PATH="/dbfs/FileStore/binaries/claude-linux-binary"

if [ -f "$DBFS_MOUNT_PATH" ]; then
    cp "$DBFS_MOUNT_PATH" ~/.local/bin/claude
    chmod +x ~/.local/bin/claude
    echo "✓ Claude CLI installed successfully"
fi
```

**Why This Works:**
- DBFS is automatically mounted at `/dbfs/` in Databricks Apps
- Direct filesystem access (no API calls needed)
- Fast (local copy operation)
- No authentication required

#### Step 3b: CLI Fallback (Backup Method)

If direct mount fails, tries Databricks CLI:

```bash
databricks fs cp dbfs:/FileStore/binaries/claude-linux-binary /tmp/claude
mv /tmp/claude ~/.local/bin/claude
chmod +x ~/.local/bin/claude
```

### 4. User Access

Once installed, users can run Claude from any terminal session:

```bash
$ claude --version
Claude Code 2.1.163

$ claude chat
# Interactive Claude session starts
```

---

## Updating the Claude Binary

### When to Update

- New Claude CLI version released
- Bug fixes in Claude CLI
- Security updates

### Update Process

#### Step 1: Download New Binary

On a machine with unrestricted internet access:

```bash
# Option A: Using WSL at home
wsl
cd /mnt/d/JM/git/experiments/source-coda
bash download-binaries-wsl.sh

# Option B: Using AWS CloudShell
curl -fsSL https://claude.ai/install.sh | bash
aws s3 cp ~/.local/share/claude/versions/$(readlink ~/.local/bin/claude | xargs basename) \
  s3://your-bucket/claude-linux-binary
```

#### Step 2: Transfer to Work Machine

Transfer the binary file to your work machine via:
- USB drive
- Personal cloud storage
- AWS S3 with presigned URL

#### Step 3: Upload to DBFS

```bash
# From your work machine
databricks fs cp /path/to/new-claude-binary \
  dbfs:/FileStore/binaries/claude-linux-binary \
  --overwrite
```

#### Step 4: Restart the App

```bash
# Redeploy to trigger reinitialization
databricks bundle deploy && databricks bundle run coda
```

**Or** users can update their existing sessions:

```bash
# In the app terminal
cp /dbfs/FileStore/binaries/claude-linux-binary ~/.local/bin/claude
chmod +x ~/.local/bin/claude
claude --version
```

---

## Troubleshooting

### Claude Command Not Found

**Check if binary exists in DBFS:**

```bash
# From local machine
databricks fs ls dbfs:/FileStore/binaries/

# From app terminal
ls -lh /dbfs/FileStore/binaries/claude-linux-binary
```

**Manual installation in app terminal:**

```bash
cp /dbfs/FileStore/binaries/claude-linux-binary ~/.local/bin/claude
chmod +x ~/.local/bin/claude
claude --version
```

### Setup Step Failed

Check the setup status:

```bash
# In browser, visit:
https://your-app-url.databricksapps.com/api/setup-status
```

Look for the "claude" step status. If it failed:

```json
{
  "id": "claude",
  "status": "error",
  "error": "DBFS direct mount not found..."
}
```

### Binary Not Executable

```bash
# Make it executable
chmod +x ~/.local/bin/claude

# Verify permissions
ls -lh ~/.local/bin/claude
# Should show: -rwxr-xr-x
```

### Wrong Architecture

Verify it's a Linux binary:

```bash
file ~/.local/bin/claude
# Should show: ELF 64-bit LSB executable, x86-64

# NOT: PE32+ (Windows) or Mach-O (Mac)
```

### DBFS Mount Not Available

If `/dbfs/` is not mounted in your environment:

```bash
# Check if mount exists
ls -ld /dbfs/
```

If not available, contact Databricks support or use the manual CLI approach:

```bash
# Use databricks CLI to download
databricks fs cp dbfs:/FileStore/binaries/claude-linux-binary /tmp/claude
cp /tmp/claude ~/.local/bin/claude
chmod +x ~/.local/bin/claude
```

---

## Alternative Approaches Tried

### ❌ Bundling Binary with Deployment

**Attempted:** Include binary in `bundled-binaries/` directory

**Why It Failed:** 
- Databricks Apps has 50 MB file size limit
- Claude binary is 234 MB
- Error: `File is larger than the maximum allowed file size of 52428800 bytes`

### ❌ Unity Catalog Volumes

**Attempted:** Store in `/Volumes/hrsandbox/cdf_trial/claude/`

**Why It Failed:**
- Volumes are not mounted in Databricks Apps containers
- Cannot access via filesystem path
- Cannot access via `databricks` CLI from within app

### ❌ S3 Direct Access

**Attempted:** Download from S3 using AWS CLI at runtime

**Why It Failed:**
- App doesn't have AWS credentials configured
- Would require additional IAM permissions
- Corporate SSL proxy blocks AWS API calls

### ❌ Download from Internet

**Attempted:** Run `curl https://claude.ai/install.sh | bash` at runtime

**Why It Failed:**
- Corporate firewall blocks external downloads
- SSL certificate validation fails (self-signed proxy cert)
- GitHub downloads blocked (installer downloads from GitHub)

### ✅ DBFS FileStore (Current Solution)

**Why It Works:**
- DBFS is mounted at `/dbfs/` in Databricks Apps
- No file size limits
- Direct filesystem access (fast)
- No authentication needed
- Persists across deployments

---

## Files Reference

| File | Purpose |
|------|---------|
| `install_claude_offline.sh` | Runtime installation script |
| `download-binaries-wsl.sh` | Download script for WSL (development) |
| `BINARY-UPDATE-INSTRUCTIONS.md` | Guide for downloading binaries |
| `databricks.yml` | App configuration with `CLAUDE_DBFS_PATH` |
| `gunicorn.conf.py` | Triggers `initialize_app()` at startup |
| `app.py` | Calls Claude setup in parallel with other CLIs |

---

## Environment Variables

| Variable | Value | Purpose |
|----------|-------|---------|
| `CLAUDE_DBFS_PATH` | `dbfs:/FileStore/binaries/claude-linux-binary` | Location of Claude binary in DBFS |
| `HOME` | `/app/python/source_code` | Home directory in app container |
| `PATH` | Includes `~/.local/bin` | Where Claude is installed |

---

## Security Considerations

### Binary Verification

The installation script does basic verification:

```bash
# Check if file exists
if [ -f "$DBFS_MOUNT_PATH" ]; then
    # Copy and make executable
    cp "$DBFS_MOUNT_PATH" "$TARGET_BINARY"
    chmod +x "$TARGET_BINARY"
fi
```

**For production, consider adding:**

1. **Checksum Verification:**
   ```bash
   # Store expected SHA256 hash
   EXPECTED_SHA="abc123..."
   ACTUAL_SHA=$(sha256sum "$TARGET_BINARY" | cut -d' ' -f1)
   if [ "$ACTUAL_SHA" != "$EXPECTED_SHA" ]; then
       echo "Checksum mismatch!"
       exit 1
   fi
   ```

2. **Binary Signing:**
   - Use GPG to sign binaries
   - Verify signature before installation

3. **Access Control:**
   - Restrict DBFS FileStore permissions
   - Use workspace-level access controls

### Current Security Posture

- ✅ Binary stored in user-accessible DBFS location
- ✅ Copied to user's local bin (not system-wide)
- ✅ No root/sudo required
- ✅ Each user gets their own copy
- ⚠️ No checksum verification (add for production)
- ⚠️ No signature verification (add for production)

---

## Performance Metrics

| Metric | Value | Notes |
|--------|-------|-------|
| Binary Size | ~234 MB | Linux x86-64 executable |
| Download Time | ~2-5 seconds | Direct copy from DBFS mount |
| Startup Impact | ~3-5 seconds | Runs in parallel with other setup |
| Storage Location | DBFS FileStore | Shared across all app instances |
| Installation Method | Direct filesystem copy | Fastest option available |

---

## Future Improvements

### Potential Enhancements

1. **Lazy Loading:**
   - Don't install Claude until first use
   - Install on-demand when user runs `claude` command

2. **Version Management:**
   - Store multiple versions in DBFS
   - Allow users to switch versions
   - Automatic updates on new releases

3. **Caching:**
   - Cache in persistent app storage
   - Only copy if version changed

4. **Multi-Binary Support:**
   - Use same approach for codex, opencode, gemini
   - Centralized binary management

5. **Checksum Verification:**
   - Add SHA256 verification
   - Store checksums alongside binaries

---

## Support

### Getting Help

1. **Check Setup Status:**
   ```
   https://your-app-url/api/setup-status
   ```

2. **View Logs:**
   Look for Claude setup messages in app startup logs

3. **Manual Installation:**
   Always available as fallback in terminal

4. **Documentation:**
   - This file: `CLAUDE-BINARY-DEPLOYMENT.md`
   - Download guide: `BINARY-UPDATE-INSTRUCTIONS.md`
   - Quick reference: `bundled-binaries/README.md`

### Common Issues

| Issue | Solution |
|-------|----------|
| Binary not found | Check DBFS path with `ls /dbfs/FileStore/binaries/` |
| Permission denied | Run `chmod +x ~/.local/bin/claude` |
| Wrong architecture | Download Linux x86-64 version, not Windows/Mac |
| Command not found | Check `echo $PATH` includes `~/.local/bin` |
| Setup failed | Run manual install commands from error message |

---

## Changelog

| Date | Version | Changes |
|------|---------|---------|
| 2026-06-05 | 1.0.0 | Initial documentation - DBFS mount approach |

---

## License

This deployment approach is part of the CoDA (Coding Agents on Databricks Apps) project.

## Credits

- Claude CLI by Anthropic
- CoDA by Databricks Solutions
- Enterprise deployment patterns by Rio Tinto IT
