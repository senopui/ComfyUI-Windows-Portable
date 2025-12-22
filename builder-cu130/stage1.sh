#!/bin/bash
set -euo pipefail

# Chores
workdir=$(pwd)
pip_exe="${workdir}/python_standalone/python.exe -s -m pip"

export PYTHONPYCACHEPREFIX="${workdir}/pycache1"
export PIP_NO_WARN_SCRIPT_LOCATION=0

ls -lahF

# Download Python 3.12 Standalone (pinned for audioop compatibility)
# Python 3.13 removed the audioop module which breaks pydub and some custom nodes
echo "=== Fetching latest Python 3.12.xx standalone build ==="
# Get the latest release (not pre-release) and find the Python 3.12.xx download URL
# 1. Fetch last 10 releases from python-build-standalone
# 2. Filter out pre-releases (select .prerelease == false)
# 3. Take the first (most recent) release
# 4. From that release's assets, find the cpython-3.12.xx install_only tarball for Windows
latest_python_url=$(curl -sSL "https://api.github.com/repos/astral-sh/python-build-standalone/releases?per_page=10" | \
    jq -r '[.[] | select(.prerelease == false)][0].assets[] | select(.name | test("cpython-3\\.12\\.[0-9]+\\+[0-9]+-x86_64-pc-windows-msvc-install_only\\.tar\\.gz$")) | .browser_download_url' | \
    head -1)

if [ -z "$latest_python_url" ]; then
    echo "ERROR: Could not find latest Python 3.12.xx release URL"
    exit 1
fi

echo "Found Python 3.12.xx at: $latest_python_url"
echo "=== Downloading Python 3.12 standalone build ==="
curl -sSL "$latest_python_url" -o python.tar.gz
tar -zxf python.tar.gz
mv python python_standalone

# PIP installs
echo "=== Installing pip, wheel, setuptools ==="
$pip_exe install --upgrade pip wheel setuptools

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
# Force binary-only install to prevent source builds which fail in CI without torch headers
echo "=== Attempting flash-attn from AI-windows-whl (binary-only) ==="
$pip_exe install flash-attn --only-binary=flash-attn --extra-index-url https://ai-windows-whl.github.io/whl/ || echo "WARNING: flash-attn binary wheel not available for this Python+PyTorch+CUDA combination"

# Guarded install: xformers via AI-windows-whl
# Install xformers normally first to get all dependencies, then check if torch was downgraded
echo "=== Attempting xformers from AI-windows-whl ==="
$pip_exe install xformers --extra-index-url https://ai-windows-whl.github.io/whl/ || echo "WARNING: xformers binary wheel not available for this Python+PyTorch+CUDA combination"

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
