#!/bin/bash
set -euo pipefail

# Chores
git config --global core.autocrlf true
workdir=$(pwd)
gcs='git clone --depth=1 --no-tags --recurse-submodules --shallow-submodules'
export PYTHONPYCACHEPREFIX="$workdir/pycache2"
export PATH="$PATH:$workdir/ComfyUI_Windows_portable/python_standalone/Scripts"

ls -lahF

# Redirect HuggingFace-Hub model folder
export HF_HUB_CACHE="$workdir/ComfyUI_Windows_portable/HuggingFaceHub"
mkdir -p "${HF_HUB_CACHE}"
# Redirect Pytorch Hub model folder
export TORCH_HOME="$workdir/ComfyUI_Windows_portable/TorchHome"
mkdir -p "${TORCH_HOME}"

# Relocate python_standalone
# This move is intentional. It will fast-fail if this breaks anything.
mv  "$workdir"/python_standalone  "$workdir"/ComfyUI_Windows_portable/python_standalone

# Add MinGit (Portable Git)
echo "=== Downloading MinGit ==="
curl -sSL https://github.com/git-for-windows/git/releases/download/v2.52.0.windows.1/MinGit-2.52.0-64-bit.zip \
    -o MinGit.zip
unzip -q MinGit.zip -d "$workdir"/ComfyUI_Windows_portable/MinGit
rm MinGit.zip

################################################################################
# ComfyUI main app - PULL FROM MASTER (NO TAG RESET)
echo "=== Cloning ComfyUI from master ==="
$gcs https://github.com/comfyanonymous/ComfyUI.git \
    "$workdir"/ComfyUI_Windows_portable/ComfyUI
cd "$workdir"/ComfyUI_Windows_portable/ComfyUI
# DO NOT reset to tag - use master as-is for nightly builds
# Clear models folder (will restore in the next stage)
rm -vrf models
mkdir models

################################################################################
# Custom Nodes - migrated from builder-cu128
cd "$workdir"/ComfyUI_Windows_portable/ComfyUI/custom_nodes

# Core
echo "=== Cloning Core nodes ==="
$gcs https://github.com/Comfy-Org/ComfyUI-Manager.git

# Performance
echo "=== Cloning Performance nodes ==="
$gcs https://github.com/city96/ComfyUI-GGUF.git
$gcs https://github.com/nunchaku-tech/ComfyUI-nunchaku.git
$gcs https://github.com/woct0rdho/ComfyUI-RadialAttn.git
$gcs https://github.com/welltop-cn/ComfyUI-TeaCache.git

# Workspace/General
echo "=== Cloning Workspace/General nodes ==="
$gcs https://github.com/crystian/ComfyUI-Crystools.git
$gcs https://github.com/pydn/ComfyUI-to-Python-Extension.git
$gcs https://github.com/bash-j/mikey_nodes.git
$gcs https://github.com/chrisgoringe/cg-use-everywhere.git
$gcs https://github.com/jags111/efficiency-nodes-comfyui.git
$gcs https://github.com/kijai/ComfyUI-KJNodes.git
$gcs https://github.com/mirabarukaso/ComfyUI_Mira.git
$gcs https://github.com/pythongosssss/ComfyUI-Custom-Scripts.git
$gcs https://github.com/rgthree/rgthree-comfy.git
$gcs https://github.com/shiimizu/ComfyUI_smZNodes.git
$gcs https://github.com/ltdrdata/was-node-suite-comfyui.git
$gcs https://github.com/yolain/ComfyUI-Easy-Use.git

# Control
echo "=== Cloning Control nodes ==="
$gcs https://github.com/chflame163/ComfyUI_LayerStyle.git
$gcs https://github.com/Fannovel16/comfyui_controlnet_aux.git
$gcs https://github.com/florestefano1975/comfyui-portrait-master.git
$gcs https://github.com/huchenlei/ComfyUI-IC-Light-Native.git
$gcs https://github.com/huchenlei/ComfyUI-layerdiffuse.git
$gcs https://github.com/Jonseed/ComfyUI-Detail-Daemon.git
$gcs https://github.com/Kosinkadink/ComfyUI-Advanced-ControlNet.git
$gcs https://github.com/ltdrdata/ComfyUI-Impact-Pack.git
$gcs https://github.com/ltdrdata/ComfyUI-Impact-Subpack.git
$gcs https://github.com/ltdrdata/ComfyUI-Inspire-Pack.git
$gcs https://github.com/mcmonkeyprojects/sd-dynamic-thresholding.git
$gcs https://github.com/twri/sdxl_prompt_styler.git

# Video
echo "=== Cloning Video nodes ==="
$gcs https://github.com/Fannovel16/ComfyUI-Frame-Interpolation.git
$gcs https://github.com/Kosinkadink/ComfyUI-AnimateDiff-Evolved.git
$gcs https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git
$gcs https://github.com/melMass/comfy_mtb.git

# More
echo "=== Cloning More nodes ==="
$gcs https://github.com/akatz-ai/ComfyUI-DepthCrafter-Nodes.git
$gcs https://github.com/digitaljohn/comfyui-propost.git
$gcs https://github.com/kijai/ComfyUI-DepthAnythingV2.git
$gcs https://github.com/kijai/ComfyUI-Florence2.git
$gcs https://github.com/pythongosssss/ComfyUI-WD14-Tagger.git
$gcs https://github.com/SLAPaper/ComfyUI-Image-Selector.git
$gcs https://github.com/ssitu/ComfyUI_UltimateSDUpscale.git

# Legacy (best-effort)
echo "=== Cloning Legacy nodes (best-effort) ==="
$gcs https://github.com/Amorano/Jovimetrix.git || echo "WARNING: Failed to clone Jovimetrix"
$gcs https://github.com/Gourieff/ComfyUI-ReActor.git || echo "WARNING: Failed to clone ComfyUI-ReActor"
$gcs https://github.com/neverbiasu/ComfyUI-SAM2.git || echo "WARNING: Failed to clone ComfyUI-SAM2"
$gcs https://github.com/cubiq/ComfyUI_InstantID.git || echo "WARNING: Failed to clone ComfyUI_InstantID"
$gcs https://github.com/cubiq/PuLID_ComfyUI.git || echo "WARNING: Failed to clone PuLID_ComfyUI"
$gcs https://github.com/cubiq/ComfyUI_FaceAnalysis.git || echo "WARNING: Failed to clone ComfyUI_FaceAnalysis"
$gcs https://github.com/akatz-ai/ComfyUI-AKatz-Nodes.git || echo "WARNING: Failed to clone ComfyUI-AKatz-Nodes"

# To-be-removed bucket (best-effort)
echo "=== Cloning To-be-removed nodes (best-effort) ==="
$gcs https://github.com/cubiq/ComfyUI_essentials.git || echo "WARNING: Failed to clone ComfyUI_essentials"
$gcs https://github.com/cubiq/ComfyUI_IPAdapter_plus.git || echo "WARNING: Failed to clone ComfyUI_IPAdapter_plus"
$gcs https://github.com/CY-CHENYUE/ComfyUI-Janus-Pro.git || echo "WARNING: Failed to clone ComfyUI-Janus-Pro"
$gcs https://github.com/FizzleDorf/ComfyUI_FizzNodes.git || echo "WARNING: Failed to clone ComfyUI_FizzNodes"
$gcs https://github.com/Suzie1/ComfyUI_Comfyroll_CustomNodes.git || echo "WARNING: Failed to clone ComfyUI_Comfyroll_CustomNodes"

################################################################################
# Copy attachments files (incl. start scripts)
echo "=== Copying attachments ==="
cp -rf "$workdir"/attachments/. \
    "$workdir"/ComfyUI_Windows_portable/
# Ensure legacy launchers are available at portable root
cp -f "$workdir"/ComfyUI_Windows_portable/ExtraScripts/run_nvidia_gpu.bat \
    "$workdir"/ComfyUI_Windows_portable/run_nvidia_gpu.bat
cp -f "$workdir"/ComfyUI_Windows_portable/ExtraScripts/run_cpu.bat \
    "$workdir"/ComfyUI_Windows_portable/run_cpu.bat

du -hd2 "$workdir"/ComfyUI_Windows_portable

################################################################################
# TAESD model for image on-the-fly preview
echo "=== Downloading TAESD decoder ==="
cd "$workdir"
$gcs https://github.com/madebyollin/taesd.git
mkdir -p "$workdir"/ComfyUI_Windows_portable/ComfyUI/models/vae_approx
cp taesd/*_decoder.pth \
    "$workdir"/ComfyUI_Windows_portable/ComfyUI/models/vae_approx/
rm -rf taesd

# Download models for ReActor
echo "=== Downloading ReActor models ==="
cd "$workdir"/ComfyUI_Windows_portable/ComfyUI/models
curl -sSL https://github.com/sczhou/CodeFormer/releases/download/v0.1.0/codeformer.pth \
    --create-dirs -o facerestore_models/codeformer-v0.1.0.pth
curl -sSL https://github.com/TencentARC/GFPGAN/releases/download/v1.3.4/GFPGANv1.4.pth \
    --create-dirs -o facerestore_models/GFPGANv1.4.pth
curl -sSL https://huggingface.co/datasets/Gourieff/ReActor/resolve/main/models/inswapper_128_fp16.onnx \
    --create-dirs -o insightface/inswapper_128_fp16.onnx
curl -sSL https://huggingface.co/AdamCodd/vit-base-nsfw-detector/resolve/main/config.json \
    --create-dirs -o nsfw_detector/vit-base-nsfw-detector/config.json
curl -sSL https://huggingface.co/AdamCodd/vit-base-nsfw-detector/resolve/main/confusion_matrix.png \
    --create-dirs -o nsfw_detector/vit-base-nsfw-detector/confusion_matrix.png
curl -sSL https://huggingface.co/AdamCodd/vit-base-nsfw-detector/resolve/main/model.safetensors \
    --create-dirs -o nsfw_detector/vit-base-nsfw-detector/model.safetensors
curl -sSL https://huggingface.co/AdamCodd/vit-base-nsfw-detector/resolve/main/preprocessor_config.json \
    --create-dirs -o nsfw_detector/vit-base-nsfw-detector/preprocessor_config.json

# Download models for Impact-Pack & Impact-Subpack (best-effort)
echo "=== Running Impact-Pack install.py (best-effort) ==="
cd "$workdir"/ComfyUI_Windows_portable/ComfyUI/custom_nodes/ComfyUI-Impact-Pack
"$workdir"/ComfyUI_Windows_portable/python_standalone/python.exe -s -B install.py || echo "WARNING: Impact-Pack install.py failed"

echo "=== Running Impact-Subpack install.py (best-effort) ==="
cd "$workdir"/ComfyUI_Windows_portable/ComfyUI/custom_nodes/ComfyUI-Impact-Subpack
"$workdir"/ComfyUI_Windows_portable/python_standalone/python.exe -s -B install.py || echo "WARNING: Impact-Subpack install.py failed"

################################################################################
# Run the test (CPU only), also let custom nodes download some models
echo "=== Running quick test with --quick-test-for-ci --cpu ==="
cd "$workdir"/ComfyUI_Windows_portable
./python_standalone/python.exe -s -B ComfyUI/main.py --quick-test-for-ci --cpu

################################################################################
# Clean up
echo "=== Cleanup ==="
# DO NOT clean pymatting cache, they are nbi/nbc files for Numba, and won't be regenerated.
#rm -rf "$workdir"/ComfyUI_Windows_portable/python_standalone/Lib/site-packages/pymatting
rm -vf "$workdir"/ComfyUI_Windows_portable/*.log
rm -vf "$workdir"/ComfyUI_Windows_portable/ComfyUI/user/*.log
rm -vrf "$workdir"/ComfyUI_Windows_portable/ComfyUI/user/default/ComfyUI-Manager

cd "$workdir"/ComfyUI_Windows_portable/ComfyUI/custom_nodes
rm -vf ./ComfyUI-Custom-Scripts/pysssss.json || echo "File not found: ComfyUI-Custom-Scripts/pysssss.json"
rm -vf ./ComfyUI-Easy-Use/config.yaml || echo "File not found: ComfyUI-Easy-Use/config.yaml"
rm -vf ./ComfyUI-Impact-Pack/impact-pack.ini || echo "File not found: ComfyUI-Impact-Pack/impact-pack.ini"
rm -vf ./Jovimetrix/web/config.json || echo "File not found: Jovimetrix/web/config.json"
rm -vf ./was-node-suite-comfyui/was_suite_config.json || echo "File not found: was-node-suite-comfyui/was_suite_config.json"

cd "$workdir"/ComfyUI_Windows_portable/ComfyUI/custom_nodes/ComfyUI-Manager
git reset --hard
git clean -fxd

cd "$workdir"
