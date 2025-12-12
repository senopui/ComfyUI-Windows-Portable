# ComfyUI Windows Portable — Copilot Instructions

## Repo overview
- Windows portable distribution of ComfyUI with 40+ custom nodes.
- Two build flavors:
  - Stable/master build: conservative, pinned for reliability.
  - Nightly/bleeding-edge build: Python 3.13 portable, PyTorch 2.10+ nightly cu130/CUDA 13, performance wheels (flash-attn, xformers, sageattention+triton-windows, natten, nunchaku, spargeattention, bitsandbytes best-effort).
- Default web UI port: 8188. Keep ASAR=false compatibility for character selector app.

## Conventions
- Portable-first: no global installs. Use embedded python_standalone and in-tree binaries.
- Bash scripts: use set -euo pipefail; keep shallow clones; avoid hard pins unless required.
- Batch launchers: use %~dp0 (it already ends with backslash). Append MinGit and python_standalone Scripts to PATH.
- Keep ComfyUI master for nightly; stable can pin if needed.

## Build/packaging notes
- Nightly: torch/vision/audio from https://download.pytorch.org/whl/nightly/cu130; perf wheels from https://ai-windows-whl.github.io/whl/; natten via https://whl.natten.org. Guard missing wheels and log warnings, don't hard-fail.
- Stages: deps → assembly → packaging. Archives named ComfyUI_Windows_portable_cu130*.7z for nightly.
- Validate launchers with --cpu --quick-test-for-ci; fail on Traceback.

## Launchers
- Max fidelity: disable xformers and smart-memory; favor stability/quality.
- Optimized fidelity: enable perf features (xformers/flash-attn/smart-memory) for balanced perf/quality.
- Keep port 8188 and portable working dir semantics.

## Security/interop
- No secrets in scripts. Preserve ports/paths expected by character selector app. Avoid breaking API surface.
