# CI Runs
## Dispatch capability
PARTIAL: GitHub CLI not available (`command -v gh` returned non-zero), but two build logs were provided externally.

## cu130 workflow
- Evidence source: `logs_53236406321.zip` → `0_build_upload.txt` (job: build_upload).
- Runner image: windows-2025 (log timestamp 2025-12-30).
- Result: **FAIL** — stage1 aborted when `pip` attempted to clone `cozy_comfy`/`cozy_comfyui` and GitHub prompted for credentials in a non-interactive context.
  - Error excerpt:
    - `fatal: Cannot prompt because user interactivity has been disabled.`
    - `fatal: could not read Username for 'https://github.com': No such file or directory`
    - `ERROR: Failed to build 'cozy_comfy'/'cozy_comfyui'`
- Additional notes:
  - `flash-attn` wheel not found for cp313/torch-nightly (skipped).
  - `spargeattention` wheel not found for this Python+PyTorch+CUDA combination (skipped).

## cu130-nightly workflow
- Evidence source: `logs_53236403191.zip` → `0_build_upload.txt` (job: build_upload).
- Runner image: windows-2025 (log timestamp 2025-12-30).
- Result: **FAIL** — stage1 aborted when `pip` attempted to clone `cozy_comfy`/`cozy_comfyui` and GitHub prompted for credentials in a non-interactive context.
  - Error excerpt:
    - `fatal: Cannot prompt because user interactivity has been disabled.`
    - `fatal: could not read Username for 'https://github.com': No such file or directory`
    - `ERROR: Failed to build 'cozy_comfy'/'cozy_comfyui'`
