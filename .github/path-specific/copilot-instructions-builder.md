# Builder Directory Instructions

This directory contains the build scripts and package manifests for creating the ComfyUI-Windows-Portable package.

## Stage 1: Python Environment Setup (stage1.sh)

### Python Installation
- **Python version**: 3.13 from python-build-standalone
- **Source**: `https://github.com/astral-sh/python-build-standalone/releases/download/20251120/cpython-3.13.9+20251120-x86_64-pc-windows-msvc-install_only.tar.gz`
- Extract to `python_standalone/` directory

### Script Conventions
```bash
#!/bin/bash
set -eux  # Exit on error, undefined variables, show commands
```

### PyTorch Installation (pak3.txt)
- **Index URL**: `https://download.pytorch.org/whl/cu130`
- Install torch, torchvision, torchaudio from cu130 nightly builds
- Note: xformers is commented out in pak3.txt

### Performance Wheels Installation

Install in this order:

1. **Core PyTorch packages** (pak3.txt)
   - torch (nightly cu130)
   - torchvision (nightly cu130)
   - torchaudio (nightly cu130)

2. **FlashAttention** (pak8.txt)
   - Source: `https://github.com/mjun0812/flash-attention-prebuild-wheels`
   - Version: 2.8.3+cu130torch2.9 for cp313
   - Wheel: `flash_attn-2.8.3+cu130torch2.9-cp313-cp313-win_amd64.whl`

3. **xformers** (installed separately if needed)
   - Compatible with cu130 PyTorch nightly
   - May be installed from curated AI-windows-whl sources

4. **SageAttention+triton-windows** (pak8.txt)
   - SageAttention: `https://github.com/woct0rdho/SageAttention`
   - Version: 2.2.0+cu130torch2.9.0andhigher
   - triton-windows: `<3.6` version paired with PyTorch
   - Ref: `https://github.com/woct0rdho/triton-windows`

5. **NATTEN** (via curated AI-windows-whl)
   - Source: Curated wheels compatible with cu130
   - Must match Python 3.13 and CUDA 13.0

6. **Nunchaku** (pak8.txt)
   - Source: `https://github.com/nunchaku-tech/nunchaku`
   - Version: 1.0.2+torch2.9 for cp313
   - Wheel: `nunchaku-1.0.2+torch2.9-cp313-cp313-win_amd64.whl`

7. **SpargeAttention** (pak8.txt)
   - Source: `https://github.com/woct0rdho/SpargeAttn`
   - Version: 0.1.0+cu130torch2.9.0

### Version Logging
Log key versions for debugging:
```bash
$pip_exe list
```

### Package Installation Order
1. pak2.txt - Basic dependencies
2. pak3.txt - PyTorch cu130 packages
3. pak4.txt - Additional ML packages
4. pak5.txt - ComfyUI dependencies
5. pak6.txt - Custom node dependencies (dlib, insightface, etc.)
6. pak7.txt - Additional tools
7. pak8.txt - Performance wheels (triton-windows, SageAttention, FlashAttention, Nunchaku)
8. ComfyUI requirements.txt (from latest tag)
9. pakY.txt - Final packages (Gooey for launcher)

## Stage 2: Repository Assembly (stage2.sh)

### Script Conventions
```bash
#!/bin/bash
set -eux
```

### ComfyUI Installation
- **Clone from master**: `git clone https://github.com/comfyanonymous/ComfyUI.git`
- **DO NOT reset to tags** - keep master branch HEAD
- Working directory: `ComfyUI_Windows_portable/ComfyUI`

### Shallow Clone Pattern
```bash
gcs='git clone --depth=1 --no-tags --recurse-submodules --shallow-submodules'
```

Use this for all custom nodes to minimize clone time and size.

### Custom Nodes Installation
Clone 40+ custom nodes including:
- ComfyUI-Manager (official)
- Performance nodes (GGUF, nunchaku, RadialAttn, TeaCache)
- Control nodes (ControlNet, IC-Light, LayerDiffuse, etc.)
- Video nodes (AnimateDiff, Frame Interpolation, VideoHelperSuite)
- Many more utility and specialized nodes

### Quick Test
Run CPU-based quick test to validate installation:
```bash
cd "$workdir"/ComfyUI_Windows_portable
./python_standalone/python.exe -s -B ComfyUI/main.py --quick-test-for-ci --cpu
```

**IMPORTANT**: Fail the build on any Traceback in output. Quick test must complete successfully.

### Attachments Copy
Copy launcher scripts and configuration files:
```bash
cp -rf "$workdir"/attachments/. "$workdir"/ComfyUI_Windows_portable/
```

This includes:
- RUN_Launcher.bat
- launcher.py
- ExtraScripts/ directory with specialized launchers

### Cleanup
- Remove log files: `*.log`
- Remove user configuration files that shouldn't be in package
- Clean ComfyUI-Manager cache with `git reset --hard && git clean -fxd`

## Stage 3: Packaging (stage3.sh)

### Script Conventions
```bash
#!/bin/bash
set -eux
```

### Package Naming
**CRITICAL**: Use `_cu130` suffix for all packages:
- Main package: `ComfyUI_Windows_portable_cu130.7z.*`
- Models package: `models.zip.*` (no cu130 suffix needed)

### Compression Settings
For 7z archives:
```bash
"C:\Program Files\7-Zip\7z.exe" a -t7z -m0=lzma2 -mx=7 -mfb=64 -md=128m -ms=on -mf=BCJ2 -v2140000000b
```

- Volume size: 2140000000 bytes (GitHub release limit)
- Use LZMA2 for speed vs size balance
- BCJ2 filter for executables

### Models Separation
1. Move models to separate directory structure
2. Restore models folder in main package (empty)
3. Package models separately as `models.zip.*`

### Split Archive Sizes
- Keep 7z split at 2140000000b (approximately 2GB)
- This avoids GitHub's 2GB file size limit

## Testing Requirements

### CPU Launcher Test
Must pass without Traceback:
```bash
./python_standalone/python.exe -s -B ComfyUI/main.py --quick-test-for-ci --cpu
```

### Log Validation
Check logs for:
- No Python Traceback errors
- Successful model downloads
- No missing dependencies

### Version Verification
Log versions of key packages:
```bash
$pip_exe list > package_versions.log
```

Key packages to verify:
- torch (nightly cu130)
- flash-attn
- sageattention
- triton-windows
- nunchaku

## Common Patterns

### Error Handling
```bash
set -euo pipefail  # Fail on any error
```

### Working Directory
```bash
workdir=$(pwd)
cd "$workdir"  # Always return to workdir
```

### Git Configuration
```bash
git config --global core.autocrlf true
```

### Environment Variables
```bash
export PYTHONPYCACHEPREFIX="$workdir/pycache1"
export PIP_NO_WARN_SCRIPT_LOCATION=0
export HF_HUB_CACHE="$workdir/ComfyUI_Windows_portable/HuggingFaceHub"
export TORCH_HOME="$workdir/ComfyUI_Windows_portable/TorchHome"
```

## Debugging Tips

### Package Installation Issues
- Check pip list output for version conflicts
- Verify cu130 index is being used
- Ensure performance wheels match Python 3.13 and CUDA 13.0

### Clone Issues
- Use shallow clones to avoid timeouts
- Check network connectivity for large repos
- Verify submodule initialization

### Test Failures
- Look for Traceback in output
- Check model download issues
- Verify all custom nodes initialized properly
