# ComfyUI Windows Portable — Copilot Instructions

## Repo overview
- Windows portable distribution of ComfyUI with 40+ custom nodes.
- Two build flavors:
  - Stable build (`builder-cu128/`): Python 3.12, PyTorch cu128/CUDA 12.8, pinned xformers==0.0.33.post2, uses latest stable ComfyUI tag.
  - Nightly build (`builder/`): Python 3.13, PyTorch nightly cu130/CUDA 13, performance wheels (flash-attn, sageattention+triton-windows, nunchaku, spargeattention), uses latest stable ComfyUI tag.
- Default web UI port: 8188. Keep ASAR=false compatibility for character selector app.

## Conventions
- Portable-first: no global installs. Use embedded python_standalone and in-tree binaries.
- Bash scripts: use `set -eux` for verbose debugging; use shallow clones `--depth=1 --no-tags --recurse-submodules --shallow-submodules`.
- Batch launchers: use `%~dp0` (already includes trailing backslash). Prepend MinGit and python_standalone Scripts to PATH.
- Both builds use latest stable ComfyUI tag (not master/main branch).

## Build/packaging notes
- Nightly (`builder/`): torch/vision/audio from https://download.pytorch.org/whl/cu130 (nightly index); perf wheels from mjun0812 (flash-attn) and woct0rdho (sageattention, spargeattention, triton-windows), nunchaku-tech (nunchaku). Xformers commented out in pak3.txt.
- Stable (`builder-cu128/`): torch/vision/audio from https://download.pytorch.org/whl/cu128; pinned xformers from PyPI.
- Stages: deps (stage1.sh) → assembly (stage2.sh) → packaging (stage3.sh). Archives: ComfyUI_Windows_portable_cu130*.7z (nightly) or ComfyUI_Windows_portable_cu128*.7z (stable).
- Validate launchers with `--quick-test-for-ci --cpu`; fail on Traceback.

## Launchers
- Default launcher (run_nvidia_gpu.bat): standard mode with xformers/flash-attn enabled by default.
- run_cpu.bat: CPU-only mode for testing.
- Keep port 8188 and portable working dir semantics.

## Security/interop
- No secrets in scripts. Preserve ports/paths expected by character selector app. Avoid breaking API surface.
