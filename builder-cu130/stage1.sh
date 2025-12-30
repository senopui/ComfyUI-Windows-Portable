#!/bin/bash
set -euo pipefail

# Chores
workdir=$(pwd)
pip_exe="${workdir}/python_standalone/python.exe -s -m pip"

export PYTHONPYCACHEPREFIX="${workdir}/pycache1"
export PIP_NO_WARN_SCRIPT_LOCATION=0

ls -lahF

# Download Python 3.13 Standalone (workflow-resolved, fallback to pinned)
python_url_default="https://github.com/astral-sh/python-build-standalone/releases/download/20251217/cpython-3.13.11%2B20251217-x86_64-pc-windows-msvc-install_only.tar.gz"
python_sha_default="1fc6f07e075da66babb806802db8c86eecf1e9d29cbcb7f00227a87947b3735a"
python_url="${PYTHON_STANDALONE_URL:-$python_url_default}"
expected_sha="${PYTHON_STANDALONE_SHA256:-}"
if [[ -z "$expected_sha" && "$python_url" != "$python_url_default" ]]; then
    echo "WARNING: Dynamic Python URL selected without SHA256; falling back to pinned URL."
    python_url="$python_url_default"
fi
if [[ -z "$expected_sha" && "$python_url" == "$python_url_default" ]]; then
    expected_sha="$python_sha_default"
fi
echo "=== Downloading Python 3.13 standalone build ==="
echo "Source: $python_url"
curl -sSL "$python_url" -o python.tar.gz
if [[ -n "$expected_sha" ]]; then
    echo "Verifying Python archive SHA256..."
    actual_sha=$(sha256sum python.tar.gz | awk '{print $1}')
    if [[ "$actual_sha" != "$expected_sha" ]]; then
        echo "ERROR: Python archive SHA256 mismatch. Expected $expected_sha got $actual_sha"
        exit 1
    fi
else
    echo "ERROR: No Python archive hash provided; SHA256 verification is required for security."
    exit 1
fi
tar -zxf python.tar.gz
mv python python_standalone

# PIP installs
echo "=== Installing pip, wheel, setuptools ==="
$pip_exe install --upgrade pip wheel setuptools

echo "=== Installing audioop-lts for Python 3.13 compatibility (pinned) ==="
$pip_exe install --only-binary=:all: "audioop-lts==0.2.1" || echo "WARNING: audioop-lts install failed (required for pydub on Python 3.13)"

echo "=== Installing pak2.txt (build tools) ==="
$pip_exe install -r "$workdir"/pak2.txt

# Install PyTorch nightly cu130 FIRST (torch 2.10+ series)
echo "=== Installing PyTorch nightly cu130 (torch>=2.10, torchvision, torchaudio) ==="
$pip_exe install -r "$workdir"/pak3.txt

# Verify torch is installed and importable before installing performance wheels
echo "=== Verifying PyTorch installation ==="
"$workdir"/python_standalone/python.exe -c "import torch; print(f'PyTorch {torch.__version__} installed successfully')" || {
    echo "ERROR: PyTorch not importable after installation"
    exit 1
}

if [[ -n "${SKIP_CORE_ATTENTION:-}" ]]; then
    echo "=== Skipping core attention installs in stage1 (managed separately) ==="
else
    # Guarded install: flash-attn via AI-windows-whl (binary-only, no source builds)
    # flash-attn requires torch to be installed first (imports torch during build)
    # Use --only-binary to prevent PEP517 source builds which fail without torch in isolation
    echo "=== Attempting flash-attn from AI-windows-whl ==="
    $pip_exe install flash-attn --only-binary :all: --extra-index-url https://ai-windows-whl.github.io/whl/ || echo "WARNING: flash-attn binary wheel not available for cp313/torch-nightly, source build prevented (skipping)"
fi

# Verify torch nightly is still installed after optional wheels (not downgraded)
echo "=== Verifying PyTorch version after optional wheels ==="
if ! "$workdir"/python_standalone/python.exe - <<'PYVER'
from packaging.version import Version, InvalidVersion
import torch

ver = getattr(torch, "__version__", None)
if not ver or not isinstance(ver, str):
    raise SystemExit("torch version is missing or invalid after optional wheels install")
base = ver.split('+', 1)[0]
try:
    parsed = Version(base)
except InvalidVersion as exc:
    raise SystemExit(f"invalid torch version string '{ver}': {exc}")
if parsed < Version("2.10.0.dev0"):
    raise SystemExit(f"torch was downgraded to {ver}, expected >=2.10.0.dev0")
if "cu130" not in ver:
    raise SystemExit(f"torch build is not cu130: {ver}")
print(f"PyTorch {ver} verified")
PYVER
then
    echo "WARNING: PyTorch version check failed, reinstalling PyTorch nightly"
    $pip_exe install --force-reinstall --no-deps -r "$workdir"/pak3.txt
    "$workdir"/python_standalone/python.exe - <<'PYVER' || { echo "ERROR: PyTorch recovery reinstall verification failed"; exit 1; }
from packaging.version import Version, InvalidVersion
import torch

ver = getattr(torch, "__version__", None)
if not ver or not isinstance(ver, str):
    raise SystemExit("torch version is missing or invalid after recovery reinstall")
base = ver.split('+', 1)[0]
try:
    parsed = Version(base)
except InvalidVersion as exc:
    raise SystemExit(f"invalid torch version string '{ver}': {exc}")
if parsed < Version("2.10.0.dev0"):
    raise SystemExit(f"torch recovery reinstall failed, got {ver}")
if "cu130" not in ver:
    raise SystemExit(f"torch recovery reinstall not cu130: {ver}")
print(f"PyTorch {ver} recovery verified")
PYVER
fi

if [[ -z "${SKIP_CORE_ATTENTION:-}" ]]; then
    # Guarded install: sageattention via AI-windows-whl
    echo "=== Attempting sageattention from AI-windows-whl ==="
    $pip_exe install sageattention --extra-index-url https://ai-windows-whl.github.io/whl/ || echo "WARNING: sageattention binary wheel not available for this Python+PyTorch+CUDA combination"

    # Guarded install: triton-windows via AI-windows-whl
    echo "=== Attempting triton-windows from AI-windows-whl ==="
    $pip_exe install 'triton-windows<3.6' --extra-index-url https://ai-windows-whl.github.io/whl/ || echo "WARNING: triton-windows binary wheel not available for this Python+PyTorch+CUDA combination"
fi

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

# Detect Python version once for binary wheel compatibility (used by dlib and insightface)
py_version=$("$workdir"/python_standalone/python.exe -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
echo "Detected Python version: $py_version"

# Guarded install: dlib (cp313 on Python 3.13, cp312 otherwise)
echo "=== Attempting dlib ==="
if [[ "$py_version" == "3.13" ]]; then
    echo "Python 3.13 detected, attempting dlib cp313 wheel"
    if ! $pip_exe install https://github.com/eddiehe99/dlib-whl/releases/download/v20.0.0-alpha/dlib-20.0.0-cp313-cp313-win_amd64.whl#sha256=9fe3b7bceb6ba0a8b92362d36535ccbccd8e65d2832804a8aa04124ec0f3a595; then
        echo "WARNING: dlib cp313 install failed, attempting cp312 fallback"
        $pip_exe install https://github.com/eddiehe99/dlib-whl/releases/download/v20.0.0-alpha/dlib-20.0.0-cp312-cp312-win_amd64.whl#sha256=417e2d7a53e65d4dbd961e616f990bab2d2faaca272b4d9f5be9ce7f2623ff60 || echo "WARNING: dlib install failed or is incompatible with Python 3.13"
    fi
else
    echo "Python $py_version detected, installing dlib cp312 wheel"
    $pip_exe install https://github.com/eddiehe99/dlib-whl/releases/download/v20.0.0-alpha/dlib-20.0.0-cp312-cp312-win_amd64.whl#sha256=417e2d7a53e65d4dbd961e616f990bab2d2faaca272b4d9f5be9ce7f2623ff60 || echo "WARNING: dlib install failed"
fi

# Guarded install: insightface (prefer cp313 on Python 3.13, fallback to cp312)
echo "=== Attempting insightface ==="
if [[ "$py_version" == "3.13" ]]; then
    echo "Python 3.13 detected, attempting insightface cp313 wheel"
    if ! $pip_exe install https://raw.githubusercontent.com/Gourieff/Assets/606558ed08f16b99a29ef30b0df0b4622164c524/Insightface/insightface-0.7.3-cp313-cp313-win_amd64.whl#sha256=7aa0ce24bc76a31d48b22f5ced38f344a857bc7d6a56071e4f23ab033a638f1c; then
        echo "WARNING: insightface cp313 wheel unavailable or incompatible, attempting cp312 fallback"
        $pip_exe install https://raw.githubusercontent.com/Gourieff/Assets/606558ed08f16b99a29ef30b0df0b4622164c524/Insightface/insightface-0.7.3-cp312-cp312-win_amd64.whl#sha256=4e58a504433ba5a500d48328689e7d6c69873165653ded7553ce804beb8723db || echo "WARNING: insightface install failed"
    fi
else
    echo "Python $py_version detected, installing insightface cp312 wheel"
    $pip_exe install https://raw.githubusercontent.com/Gourieff/Assets/606558ed08f16b99a29ef30b0df0b4622164c524/Insightface/insightface-0.7.3-cp312-cp312-win_amd64.whl#sha256=4e58a504433ba5a500d48328689e7d6c69873165653ded7553ce804beb8723db || echo "WARNING: insightface install failed"
fi

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
echo "Verifying final torch version is cu130 and >=2.10:"
"$workdir"/python_standalone/python.exe - <<'PYVER'
from packaging.version import Version, InvalidVersion
import torch

ver = getattr(torch, "__version__", None)
if not ver or not isinstance(ver, str):
    raise SystemExit("ERROR: torch version is missing or invalid in final verification")
base = ver.split('+', 1)[0]
try:
    parsed = Version(base)
except InvalidVersion as exc:
    raise SystemExit(f"ERROR: torch version string '{ver}' is invalid: {exc}")
if parsed < Version("2.10.0.dev0"):
    raise SystemExit(f"ERROR: torch is {ver}, expected >=2.10.0.dev0 with cu130 build")
if "cu130" not in ver:
    raise SystemExit(f"ERROR: torch build is not cu130: {ver}")
print("[OK] PyTorch cu130 2.10+ verified")
PYVER
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
