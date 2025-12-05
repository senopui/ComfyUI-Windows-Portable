#!/bin/bash
set -eux

# Chores
workdir=$(pwd)
pip_exe="${workdir}/python_standalone/python.exe -s -m pip"

export PYTHONPYCACHEPREFIX="${workdir}/pycache1"
export PIP_NO_WARN_SCRIPT_LOCATION=0

ls -lahF

# Download Python Standalone - Python 3.13 for nightly build
curl -sSL \
https://github.com/astral-sh/python-build-standalone/releases/download/20251120/cpython-3.13.9+20251120-x86_64-pc-windows-msvc-install_only.tar.gz \
    -o python.tar.gz
tar -zxf python.tar.gz
mv python python_standalone

# PIP installs
$pip_exe install --upgrade pip wheel setuptools

$pip_exe install -r "$workdir"/pak2.txt
$pip_exe install -r "$workdir"/pak3.txt

# Install PyTorch nightly for bleeding-edge features
$pip_exe install --pre --upgrade torch torchvision torchaudio --index-url https://download.pytorch.org/whl/nightly/cu130

# Install bleeding-edge wheels from AI-windows-whl repository
# FlashAttention, xformers, SageAttention+triton-windows, NATTEN, etc.
$pip_exe install --extra-index-url https://ai-windows-whl.github.io/whl/ xformers
$pip_exe install --extra-index-url https://ai-windows-whl.github.io/whl/ flash-attn || echo "FlashAttention install skipped (may not be available)"
$pip_exe install --extra-index-url https://ai-windows-whl.github.io/whl/ sageattention || echo "SageAttention install skipped (may not be available)"
$pip_exe install --extra-index-url https://ai-windows-whl.github.io/whl/ triton-windows || echo "triton-windows install skipped (may not be available)"
$pip_exe install --extra-index-url https://ai-windows-whl.github.io/whl/ natten || echo "NATTEN install skipped (may not be available)"

# temp-fix, TODO: remove after version chaos resolved
$pip_exe install transformers

$pip_exe install -r "$workdir"/pak4.txt
$pip_exe install -r "$workdir"/pak5.txt
$pip_exe install -r "$workdir"/pak6.txt
$pip_exe install -r "$workdir"/pak7.txt

# temp-fix: Prevent SAM-3 from installing its older dependencies
$pip_exe install --no-deps 'git+https://github.com/facebookresearch/sam3.git'

# Install pak8.txt packages with error handling for compatibility
# These may fail with Python 3.13 / PyTorch nightly - that's expected for bleeding-edge builds
while IFS= read -r line || [ -n "$line" ]; do
    # Skip comments and empty lines
    [[ "$line" =~ ^#.*$ ]] || [[ -z "$line" ]] && continue
    echo "Attempting to install: $line"
    $pip_exe install "$line" || echo "Warning: Failed to install $line (may be incompatible with Python 3.13 / PyTorch nightly)"
done < "$workdir"/pak8.txt

# Install comfyui-frontend-package from master branch for nightly builds
$pip_exe install -r "https://github.com/comfyanonymous/ComfyUI/raw/refs/heads/master/requirements.txt"

$pip_exe install -r "$workdir"/pakY.txt
$pip_exe install -r "$workdir"/pakZ.txt

$pip_exe list

cd "$workdir"

# Add Ninja binary (replacing PIP Ninja if exists)
curl -sSL https://github.com/ninja-build/ninja/releases/latest/download/ninja-win.zip \
    -o ninja-win.zip
unzip -q -o ninja-win.zip -d "$workdir"/python_standalone/Scripts
rm ninja-win.zip

# Add aria2 binary
curl -sSL https://github.com/aria2/aria2/releases/download/release-1.37.0/aria2-1.37.0-win-64bit-build1.zip \
    -o aria2.zip
unzip -q aria2.zip -d "$workdir"/aria2
mv "$workdir"/aria2/*/aria2c.exe  "$workdir"/python_standalone/Scripts/
rm aria2.zip

# Add FFmpeg binary
curl -sSL https://github.com/GyanD/codexffmpeg/releases/download/8.0.1/ffmpeg-8.0.1-full_build.zip \
    -o ffmpeg.zip
unzip -q ffmpeg.zip -d "$workdir"/ffmpeg
mv "$workdir"/ffmpeg/*/bin/ffmpeg.exe  "$workdir"/python_standalone/Scripts/
rm ffmpeg.zip

cd "$workdir"
du -hd1
