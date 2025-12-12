# ComfyUI Windows Portable — Copilot Instructions

## Repo overview
- Windows portable distribution of ComfyUI with 40+ custom nodes.
- Two build flavors:
  - Stable/master build: conservative, pinned for reliability.
  - Nightly/bleeding-edge build: Python 3.13 portable, PyTorch 2.10+ nightly cu130/CUDA 13, performance wheels (flash-attn, xformers, sageattention+triton-windows, natten, nunchaku, spargeattention, bitsandbytes best-effort).
- Default web UI port: 8188. Keep ASAR=false compatibility for character selector app.

## Conventions
- Portable-first: no global installs. Use embedded python_standalone and in-tree binaries.
- Bash scripts: use `set -euo pipefail`; keep shallow clones; avoid hard pins unless required.
- Batch launchers: use `%~dp0` (it already ends with backslash). Append MinGit and python_standalone Scripts to PATH.
- Keep ComfyUI master for nightly; stable can pin if needed.

## Build/packaging notes
- Nightly: torch/vision/audio from https://download.pytorch.org/whl/nightly/cu130; perf wheels from https://ai-windows-whl.github.io/whl/; natten via https://whl.natten.org. Guard missing wheels and log warnings, don't hard-fail.
- Stages: deps → assembly → packaging. Archives named ComfyUI_Windows_portable_cu130*.7z for nightly.
- Validate launchers with `--quick-test-for-ci --cpu`; fail on Traceback.
- Python version: 3.13 from python-build-standalone for nightly builds.
- 7z compression: volume splits at 2140000000 bytes (GitHub release limit).

## Build stages (builder directory)
### Stage 1: Python Environment Setup (stage1.sh)
- Python 3.13 from python-build-standalone (nightly builds)
- Package installation order: pak2.txt → pak3.txt (PyTorch cu130) → pak4.txt → pak5.txt → pak6.txt → pak7.txt → pak8.txt (perf wheels) → ComfyUI requirements.txt → pakY.txt → pakZ.txt
- Performance wheels: flash-attn, xformers, sageattention+triton-windows, natten, nunchaku, spargeattention (best-effort)
- Log package versions with `pip list` for debugging

### Stage 2: Repository Assembly (stage2.sh)
- Clone ComfyUI from master (DO NOT reset to tags for nightly)
- Use shallow clone pattern: `git clone --depth=1 --no-tags --recurse-submodules --shallow-submodules`
- Clone 40+ custom nodes using shallow clones
- Quick test: `python_standalone/python.exe -s -B ComfyUI/main.py --quick-test-for-ci --cpu`
- IMPORTANT: Fail build on any Traceback in output
- Copy attachments (launchers, ExtraScripts) to portable directory
- Clean ComfyUI-Manager cache: `git reset --hard && git clean -fxd`

### Stage 3: Packaging (stage3.sh)
- Package naming: `ComfyUI_Windows_portable_cu130*.7z` for nightly
- Separate models into `models.zip.*`
- 7z compression with BCJ2 filter and volume splits

## Launchers (ExtraScripts directory)
### Maximum Fidelity (`run_maximum_fidelity.bat`)
- Command: `.\python_standalone\python.exe -s -B ComfyUI\main.py --disable-xformers --disable-smart-memory %*`
- Purpose: Disables performance optimizations (xformers, smart memory) for best quality and stability
- Use case: Production renders, final quality outputs

### Optimized Fidelity (`run_optimized_fidelity.bat`)
- Command: `.\python_standalone\python.exe -s -B ComfyUI\main.py %*`
- Purpose: Default settings with all performance optimizations enabled (xformers, FlashAttention, smart memory)
- Use case: Interactive work, fast iterations, development

### Common launcher elements
- Set PATH: `set PATH=%PATH%;%~dp0MinGit\cmd;%~dp0python_standalone\Scripts`
- Environment variables: `HF_HUB_CACHE=%~dp0HuggingFaceHub`, `TORCH_HOME=%~dp0TorchHome`, `PYTHONPYCACHEPREFIX=%~dp0pycache`
- Use `.\` prefix for current directory executables
- Always use `%*` for argument pass-through
- Keep port 8188 and portable working dir semantics
- Structure: `@echo off`, `setlocal`, commands, `endlocal`, `pause`

## Security/interop
- No secrets in scripts. Preserve ports/paths expected by character selector app. Avoid breaking API surface.
