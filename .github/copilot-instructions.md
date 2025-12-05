# ComfyUI-Windows-Portable Repository Instructions

## Overview
ComfyUI-Windows-Portable is a Windows portable package with 40+ custom nodes pre-installed. This is a nightly/bleeding-edge build using CUDA 13 and PyTorch nightly stack with performance-optimized wheels.

- **Default port**: 8188
- **Stack**: Python 3.13, PyTorch nightly with CUDA 13.0
- **Performance wheels**: FlashAttention, xformers, SageAttention+triton-windows, NATTEN (via curated AI-windows-whl wheels)
- **Compatibility**: Works with character_select_stand_alone_app_test

## Tech Stack & Runtime

### Python Environment
- **Python version**: 3.13 (from python-build-standalone)
- **PyTorch**: Nightly builds with cu130 index
- **Index URL**: `https://download.pytorch.org/whl/cu130`

### Important Notes
- Keep `--asar=false` note in documentation where applicable
- Default web UI port is 8188 (do not change)
- Uses `python_standalone` directory for Python installation

## Coding & Style Guidelines

### Bash Scripts
- Always use `set -euo pipefail` at the beginning of bash scripts
- Use `set -eux` for scripts that need verbose debugging output
- Enable shallow clones: `git clone --depth=1 --no-tags --recurse-submodules --shallow-submodules`
- Log key versions for debugging purposes

### Batch File Patterns
- Use `%~dp0` for script directory navigation (includes trailing backslash)
- Prepend portable Git to PATH: `set PATH=%PATH%;%~dp0MinGit\cmd`
- Use `setlocal`/`endlocal` for environment isolation

### Dependency Management
- Avoid version pinning unless absolutely necessary
- Install from nightly/bleeding-edge sources when possible
- Use cu130 index for PyTorch and related packages

## Security Guidelines
- Never commit secrets or tokens to repository
- Validate all user inputs
- Preserve default ports and paths (port 8188)
- Don't expose sensitive information in logs

## Build & Packaging Process

### Stage 1: Python Environment Setup (stage1.sh)
- Download and extract Python 3.13 standalone build
- Install pip, wheel, setuptools
- Install PyTorch nightly from cu130 index (pak3.txt)
- Install performance wheels:
  - FlashAttention (via mjun0812 prebuild wheels)
  - xformers (commented out in pak3.txt, installed elsewhere)
  - SageAttention+triton-windows (woct0rdho builds)
  - NATTEN (via curated AI-windows-whl)
  - Nunchaku (nunchaku-tech)
- Install packages from pak2.txt through pak8.txt and pakY.txt
- Use cu130 index URL for all PyTorch-related packages

### Stage 2: Repository Assembly (stage2.sh)
- Clone ComfyUI from master branch (do not reset to tags)
- Use shallow clones for all custom nodes
- Clone 40+ custom nodes from various repositories
- Copy attachments (including launchers) to build directory
- Run quick test with `--quick-test-for-ci --cpu` flag
- Fail build on any Traceback in CPU launcher tests

### Stage 3: Packaging (stage3.sh)
- Package naming: `ComfyUI_Windows_portable_cu130.7z.*`
- Separate models into `models.zip.*` split archives
- Use 7z with specific compression settings
- Split archives at 2140000000 bytes (GitHub limits)
- Maintain separate models and main package

## Launchers

**Note**: Launchers in ExtraScripts/ are meant to be copied to the installation root directory before use. Once copied, they use relative paths to access ComfyUI components.

### run_maximum_fidelity.bat
- Command: `.\python_standalone\python.exe -s -B ComfyUI\main.py --disable-xformers --disable-smart-memory %*`
- Uses relative paths (launcher is in installation root)
- Prepend portable Git to PATH using %~dp0
- Comments should explain focus on fidelity/stability over speed

### run_optimized_fidelity.bat
- Command: `.\python_standalone\python.exe -s -B ComfyUI\main.py %*`
- Uses default settings with xformers/FlashAttention enabled
- Uses relative paths (launcher is in installation root)
- Note auto-precision optimization
- Prepend portable Git to PATH using %~dp0

### PATH Configuration
All launchers should prepend portable Git (no backslash after %~dp0):
```batch
set PATH=%PATH%;%~dp0MinGit\cmd;%~dp0python_standalone\Scripts
```

## CI Workflow

### Runner Configuration
- Uses `windows-latest` runner
- Runs all stages in bash shell
- Working directory: `builder/`

### Testing Steps
1. Quick test during Stage 2 with `--quick-test-for-ci --cpu`
2. CPU launcher validation (must not show Traceback)
3. Log validation to ensure no critical errors

### Artifact Upload
- Upload split archives (*.7z* and *.zip*) to draft release
- Always create draft before release
- Allow overwrite of existing files

## Compatibility Requirements

### Configuration Files
- Keep `extra_model_paths.yaml.example` unchanged
- Maintain default port 8188
- Don't change ComfyUI API surface

### Backward Compatibility
- Package structure must remain consistent for upgrades
- Model paths should be compatible with previous versions
- Launcher behavior should not break existing workflows

## Common Commands

### Git Operations
```bash
# Always disable pager for CI
git --no-pager status
git --no-pager diff

# Shallow clone pattern
git clone --depth=1 --no-tags --recurse-submodules --shallow-submodules <repo>
```

### Build Commands
```bash
# Stage execution
bash stage1.sh  # Python setup
bash stage2.sh  # Assembly
bash stage3.sh  # Packaging
```

### Testing
```bash
# Quick test
./python_standalone/python.exe -s -B ComfyUI/main.py --quick-test-for-ci --cpu
```
