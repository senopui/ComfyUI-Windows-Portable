#!/bin/bash
set -euo pipefail

# Chores
workdir=$(pwd)
pip_exe="${workdir}/python_standalone/python.exe -s -m pip"

export PYTHONPYCACHEPREFIX="${workdir}/pycache1"
export PIP_NO_WARN_SCRIPT_LOCATION=0

ls -lahF

# Download Python 3.12 Standalone (pinned for audioop compatibility and supply-chain security)
# Python 3.13 removed the audioop module which breaks pydub and some custom nodes
# Pinned to specific release to prevent supply-chain attacks via compromised upstream
echo "=== Downloading Python 3.12.12+20251217 standalone build ==="
curl -sSL \
    https://github.com/astral-sh/python-build-standalone/releases/download/20251217/cpython-3.12.12%2B20251217-x86_64-pc-windows-msvc-install_only.tar.gz \
    -o python.tar.gz
tar -zxf python.tar.gz
mv python python_standalone

# PIP installs
echo "=== Installing pip, wheel, setuptools ==="
$pip_exe install --upgrade pip wheel setuptools

echo "=== Installing audioop-lts for Python 3.13 compatibility (pinned) ==="
$pip_exe install --only-binary=:all: "audioop-lts==0.2.1" || echo "WARNING: audioop-lts install failed (required for pydub on Python 3.13)"

echo "=== Installing pak2.txt (build tools) ==="
$pip_exe install -r "$workdir"/pak2.txt

# Install PyTorch nightly cu130 FIRST
echo "=== Installing PyTorch nightly cu130 (torch, torchvision, torchaudio) ==="
$pip_exe install -r "$workdir"/pak3.txt

# Verify torch is installed and importable before installing performance wheels
echo "=== Verifying PyTorch installation ==="
"$workdir"/python_standalone/python.exe -c "import torch; print(f'PyTorch {torch.__version__} installed successfully')" || {
    echo "ERROR: PyTorch not importable after installation"
    exit 1
}

# Guarded install: flash-attn via AI-windows-whl (binary-only, no source builds)
# flash-attn requires torch to be installed first (imports torch during build)
# Use --only-binary to prevent PEP517 source builds which fail without torch in isolation
echo "=== Attempting flash-attn from AI-windows-whl ==="
$pip_exe install flash-attn --only-binary :all: --extra-index-url https://ai-windows-whl.github.io/whl/ || echo "WARNING: flash-attn binary wheel not available for cp313/torch-nightly, source build prevented (skipping)"

# Guarded install: xformers via AI-windows-whl
# Attempt binary-only xformers install (with its bundled dependencies), then check if torch was downgraded
# Use --only-binary to avoid building from source (avoids mismatched torch/python versions)
echo "=== Attempting xformers from AI-windows-whl ==="
$pip_exe install xformers --only-binary :all: --extra-index-url https://ai-windows-whl.github.io/whl/ || echo "WARNING: xformers binary wheel not available for cp313/torch-nightly, source build prevented (skipping)"

# Verify torch nightly is still installed after xformers (not downgraded)
echo "=== Verifying PyTorch version after xformers install ==="
"$workdir"/python_standalone/python.exe -c "import torch; assert 'cu130' in torch.__version__ and 'dev' in torch.__version__, f'torch was downgraded to {torch.__version__}'; print(f'PyTorch {torch.__version__} verified')" || {
    echo "WARNING: PyTorch version check failed, reinstalling PyTorch nightly"
    $pip_exe install --force-reinstall --no-deps -r "$workdir"/pak3.txt
    # Verify recovery reinstall succeeded
    "$workdir"/python_standalone/python.exe -c "import torch; assert 'cu130' in torch.__version__ and 'dev' in torch.__version__, f'torch recovery reinstall failed, got {torch.__version__}'; print(f'PyTorch {torch.__version__} recovery verified')" || {
        echo "ERROR: PyTorch recovery reinstall failed, aborting build"
        exit 1
    }
}

# Guarded install: sageattention via AI-windows-whl
echo "=== Attempting sageattention from AI-windows-whl ==="
$pip_exe install sageattention --extra-index-url https://ai-windows-whl.github.io/whl/ || echo "WARNING: sageattention binary wheel not available for this Python+PyTorch+CUDA combination"

# Guarded install: triton-windows via AI-windows-whl
echo "=== Attempting triton-windows from AI-windows-whl ==="
$pip_exe install 'triton-windows<3.6' --extra-index-url https://ai-windows-whl.github.io/whl/ || echo "WARNING: triton-windows binary wheel not available for this Python+PyTorch+CUDA combination"

# Guarded install: natten via whl.natten.org
echo "=== Attempting natten from whl.natten.org ==="
$pip_exe install natten -f https://whl.natten.org || echo "WARNING: natten binary wheel not available for this Python+PyTorch+CUDA combination"

# Guarded install: nunchaku via AI-windows-whl
echo "=== Attempting nunchaku from AI-windows-whl ==="
$pip_exe install nunchaku --extra-index-url https://ai-windows-whl.github.io/whl/ || echo "WARNING: nunchaku binary wheel not available for this Python+PyTorch+CUDA combination"

# Guarded install: spargeattention via AI-windows-whl
echo "=== Attempting spargeattention from AI-windows-whl ==="
$pip_exe install spargeattention --extra-index-url https://ai-windows-whl.github.io/whl/ || echo "WARNING: spargeattention binary wheel not available for this Python+PyTorch+CUDA combination"

# Guarded install: bitsandbytes
echo "=== Attempting bitsandbytes ==="
$pip_exe install bitsandbytes || echo "WARNING: bitsandbytes binary wheel not available for this Python+PyTorch+CUDA combination"

# temp-fix, TODO: remove after version chaos resolved
echo "=== Installing transformers ==="
$pip_exe install transformers

echo "=== Installing pak4.txt ==="
$pip_exe install -r "$workdir"/pak4.txt

echo "=== Installing pak5.txt ==="
$pip_exe install -r "$workdir"/pak5.txt

echo "=== Installing pak6.txt ==="
$pip_exe install -r "$workdir"/pak6.txt

# Guarded install: dlib (cp312 wheel is compatible with Python 3.12)
echo "=== Attempting dlib ==="
$pip_exe install https://github.com/eddiehe99/dlib-whl/releases/download/v20.0.0-alpha/dlib-20.0.0-cp312-cp312-win_amd64.whl || echo "WARNING: dlib install failed"

# Guarded install: insightface (cp312 wheel is compatible with Python 3.12)
echo "=== Attempting insightface ==="
$pip_exe install https://github.com/Gourieff/Assets/raw/refs/heads/main/Insightface/insightface-0.7.3-cp312-cp312-win_amd64.whl || echo "WARNING: insightface install failed"

# Guarded install: cupy for CUDA 13.0 (try cuda13x first, fallback to cuda12x)
echo "=== Attempting cupy-cuda13x (fallback to cuda12x if unavailable) ==="
$pip_exe install cupy-cuda13x || $pip_exe install cupy-cuda12x || echo "WARNING: cupy install failed for both cuda13x and cuda12x"

echo "=== Installing pak7.txt ==="
$pip_exe install -r "$workdir"/pak7.txt

# temp-fix: Prevent SAM-3 from installing its older dependencies
echo "=== Installing SAM3 (no-deps) ==="
$pip_exe install --no-deps 'git+https://github.com/facebookresearch/sam3.git'

# Install packages from pak8.txt with clear logging
echo "=== Installing pak8.txt (performance wheels - best effort) ==="
while IFS= read -r line || [ -n "$line" ]; do
    # Skip empty lines and comments
    if [[ -z "$line" ]] || [[ "$line" =~ ^[[:space:]]*# ]]; then
        continue
    fi
    echo ">>> Installing: $line"
    $pip_exe install "$line" || echo "WARNING: Failed to install $line (binary wheel not available for this Python+PyTorch+CUDA combination)"
done < "$workdir"/pak8.txt

# Install comfyui-frontend-package from ComfyUI master
echo "=== Installing ComfyUI frontend requirements from master ==="
$pip_exe install -r "https://github.com/comfyanonymous/ComfyUI/raw/refs/heads/master/requirements.txt" || echo "WARNING: ComfyUI frontend requirements install had issues"

echo "=== Installing pakY.txt ==="
$pip_exe install -r "$workdir"/pakY.txt

echo "=== Installing pakZ.txt ==="
$pip_exe install -r "$workdir"/pakZ.txt

# Log Python/PyTorch/CUDA versions
echo "=============================="
echo "=== Final Version Summary ==="
echo "=============================="
echo "Python version:"
"$workdir"/python_standalone/python.exe --version
echo "---"
echo "PyTorch version and CUDA availability:"
"$workdir"/python_standalone/python.exe -c "import torch; print(f'PyTorch: {torch.__version__}'); print(f'CUDA available: {torch.cuda.is_available()}'); print(f'CUDA version: {torch.version.cuda if torch.cuda.is_available() else \"N/A\"}')" || echo "WARNING: Could not query PyTorch/CUDA info"
echo "---"
echo "Checking numpy and opencv versions:"
"$workdir"/python_standalone/python.exe -c "import numpy, cv2; print(f'numpy: {numpy.__version__}'); print(f'opencv: {cv2.__version__}')" || echo "WARNING: Could not query numpy/opencv versions"
echo "---"
echo "Verifying final torch version is cu130 nightly:"
"$workdir"/python_standalone/python.exe -c "import torch; assert 'cu130' in torch.__version__ and 'dev' in torch.__version__, f'ERROR: torch is {torch.__version__}, expected cu130 nightly'; print('[OK] PyTorch cu130 nightly verified')" || {
    echo "ERROR: Final torch version verification failed!"
    echo "This build requires PyTorch nightly cu130 but found a different version."
    exit 1
}
echo "=============================="

$pip_exe list

cd "$workdir"

# Add Ninja binary (replacing PIP Ninja if exists)
echo "=== Adding Ninja binary ==="
curl -sSL https://github.com/ninja-build/ninja/releases/latest/download/ninja-win.zip \
    -o ninja-win.zip
unzip -q -o ninja-win.zip -d "$workdir"/python_standalone/Scripts
rm ninja-win.zip

# Add aria2 binary
echo "=== Adding aria2 binary ==="
curl -sSL https://github.com/aria2/aria2/releases/download/release-1.37.0/aria2-1.37.0-win-64bit-build1.zip \
    -o aria2.zip
unzip -q aria2.zip -d "$workdir"/aria2
mv "$workdir"/aria2/*/aria2c.exe  "$workdir"/python_standalone/Scripts/
rm aria2.zip

# Add FFmpeg binary
echo "=== Adding FFmpeg binary ==="
curl -sSL https://github.com/GyanD/codexffmpeg/releases/download/8.0.1/ffmpeg-8.0.1-full_build.zip \
    -o ffmpeg.zip
unzip -q ffmpeg.zip -d "$workdir"/ffmpeg
mv "$workdir"/ffmpeg/*/bin/ffmpeg.exe  "$workdir"/python_standalone/Scripts/
rm ffmpeg.zip

cd "$workdir"
du -hd1
