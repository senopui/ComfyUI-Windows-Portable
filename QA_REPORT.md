# QA Report

## Upstream Sync
- Upstream: `https://github.com/YanWenKun/ComfyUI-Windows-Portable` (default branch `main`)
- Before sync SHA: `e906265c2f45cf1470549a8f14438da225d65f05`
- After sync SHA: `ea7bc5ca56bb0fc3223634767c89a4d3e3a25fc9`
- Notable upstream changes: workflow/test-build improvements and builder updates; no breaking dependency changes noted.

## CI Failure Evidence (CUDA 13.0 Nightly)
| Run Date (UTC) | Run ID | Failing Step | Error Excerpt | Failure Class |
| --- | --- | --- | --- | --- |
| 2025-12-21 | [20403953035](https://github.com/senopui/ComfyUI-Windows-Portable/actions/runs/20403953035) | Stage 1 Gathering Dependencies | `UnicodeEncodeError: 'charmap' codec can't encode character '\u2713' in position 0: character maps to <undefined>` during torch nightly verification in `builder-cu130/stage1.sh` line 166 | Encoding/locale |
| 2025-12-20 | [20388197571](https://github.com/senopui/ComfyUI-Windows-Portable/actions/runs/20388197571) | Stage 1 Gathering Dependencies | `UnicodeEncodeError: 'charmap' codec can't encode character '\\u2713' in position 0: character maps to <undefined>` - Same root cause as above | Encoding/locale |
| 2025-12-19 | [20358633634](https://github.com/senopui/ComfyUI-Windows-Portable/actions/runs/20358633634) | Stage 1 Gathering Dependencies | `UnicodeEncodeError: 'charmap' codec can't encode character '\\u2713' in position 0: character maps to <undefined>` - Same root cause as above | Encoding/locale |

Root cause: cp1252 encoding on Windows runners could not emit the checkmark (✓) used in torch cu130 nightly assertion logging. The error occurred when Python's print() statement attempted to output the Unicode character U+2713 (✓) to a console using Windows-1252 encoding.

## Fixes & Hardening
- Replaced the non-ASCII checkmark (✓) in `builder-cu130/stage1.sh` torch cu130 nightly assertion output with `[OK]` to avoid cp1252 encoding failures.
- Replaced non-ASCII checkmarks (✓ and ✗) in `.github/workflows/copilot-setup-steps.yml` with ASCII equivalents (`OK` and `FAIL`).
- Restored full environment setup (setlocal, PATH, PYTHONPYCACHEPREFIX) in `builder/attachments/ExtraScripts/run_cpu.bat` and `builder-cu128/attachments/ExtraScripts/run_cpu.bat` to ensure custom nodes requiring git can access MinGit.
- Restored `-B` flag to Python invocations in `builder/attachments/ExtraScripts/run_nvidia_gpu.bat` and `builder-cu128/attachments/ExtraScripts/run_nvidia_gpu.bat` to prevent .pyc file writes.
- Added artifact layout validation to the CUDA 13 nightly workflow to fail fast if the packaged portable tree is incomplete.

## New QA Assets
- `scripts/qa_smoketest_windows.ps1`: CPU headless smoke test; logs to `<portable>/logs/qa-smoketest.log`; fails on Traceback/import/DLL errors.
  - **LIMITATION**: This CPU smoke test does NOT validate GPU extension loading (e.g., CUDA, xformers, flash-attention). It only confirms that ComfyUI can start without import errors on CPU mode.
  - Optional: set `QA_DISABLE_WINDOWS_STANDALONE=1` to skip the `--windows-standalone-build` flag if running against a non-portable install.
- `scripts/qa_validate_workflow.py`: Validates node availability for `tests/workflows/minimal_text2img.json`.
  - **LIMITATION**: This validator only checks base ComfyUI nodes present in the core repository. It does NOT validate custom nodes from `custom_nodes/` directory.
- `tests/workflows/minimal_text2img.json`: Minimal text-to-image workflow fixture for validation.
- Windows CI smoke test added to `.github/workflows/test-build.yml` (runs `scripts/qa_smoketest_windows.ps1` on `windows-latest`).

## Commands to Run Manually
- CUDA nightly build: `bash builder-cu130/stage1.sh && bash builder-cu130/stage2.sh && bash builder-cu130/stage3.sh`
- Artifact validation (workflow step): run job “Build & Upload CUDA 13.0 Nightly Package”.
- CPU smoke test: `pwsh ./scripts/qa_smoketest_windows.ps1`
- Workflow validation: `python ./scripts/qa_validate_workflow.py`

## Expected Outputs
- Smoke test log: `<portable>/logs/qa-smoketest.log` contains no `Traceback`, `ImportError`, or DLL load errors.
- Workflow validator prints `Workflow node validation passed.` and exits 0.
- CUDA nightly build no longer fails on UnicodeEncodeError in Stage 1; proceeds to later stages unless other issues arise.

## Dependency Versions
Expected dependency versions for each builder configuration:

### builder-cu130 (CUDA 13.0 Nightly)
- **Python**: 3.12.x (embedded in `python_standalone/`)
- **PyTorch**: 2.7.0.dev (nightly) with CUDA 13.0 support (`cu130` in version string)
- **CUDA Toolkit**: 13.0
- **Key Performance Libraries**:
  - xformers (nightly, post-cu130 PyTorch install)
  - flash-attn (optional, guarded install)
  - triton (typically included with PyTorch nightly)

### builder-cu128 (CUDA 12.8)
- **Python**: 3.12.x (embedded in `python_standalone/`)
- **PyTorch**: Compatible with CUDA 12.8
- **CUDA Toolkit**: 12.8

### builder (Legacy/CPU)
- **Python**: 3.12.x (embedded in `python_standalone/`)
- **PyTorch**: CPU-only build

**Note**: Exact version numbers vary as nightly builds update daily. Stage 1 scripts verify PyTorch CUDA variant post-install. Run `python_standalone/python.exe -m pip list` in built portable tree to see installed versions.

## Validation Status
- **actionlint**: run locally (v1.7.9) – no issues.
- **QA scripts (smoketest, workflow validator)**: **not run** in this environment because ComfyUI portable tree is not present. Commands to execute after build:
  - `pwsh ./scripts/qa_smoketest_windows.ps1`
  - `python ./scripts/qa_validate_workflow.py`
- **CodeQL**: **not run** (current configuration did not detect analyzable language changes; rerun when supported-language code changes are present).
- **GPU validation**: **not performed in CI** (Windows runners lack CUDA hardware); manual GPU validation required on physical hardware (see Manual QA section).

## Manual QA (Windows 11 + NVIDIA, guidance)
1. Run `scripts/qa_smoketest_windows.ps1` (expects ComfyUI portable tree with python_standalone and ComfyUI).
2. Launch `run_nvidia_gpu.bat` and confirm web UI loads on port 8188; run a simple workflow (e.g., minimal_text2img.json with a valid checkpoint).
3. Check `logs/` for absence of Tracebacks.

## Remaining Risks
- GPU inference not exercised in CI (Windows runners lack CUDA); manual GPU validation still required.
- Artifact validation only checks presence of key files, not full runtime.
- QA scripts not yet executed here; run post-build on Windows with assembled portable tree to confirm runtime.

## Runtime Startup Log Triage
**Source log**: `ComfyUI_Windows_portable-Running-Log.txt` (attached in PR comment on 2025-12-29). Re-run with logging enabled to generate `<portable>/logs/qa-smoketest.log` via `pwsh ./scripts/qa_smoketest_windows.ps1`.

| Exception Signature | Module/Component | Optional/Required | Evidence | PR / Fix |
| --- | --- | --- | --- | --- |
| `ImportError: DLL load failed while importing _C` (xformers → `flash_attn_3`) | xformers / flash-attn interoperability; diffusers import path | Required for diffusers-backed nodes | `diffusers.models.attention_processor` → `xformers.ops` → `flash_attn_3` import fails; cascades into `ComfyUI-DepthCrafter-Nodes`, `ComfyUI-layerdiffuse`, `ComfyUI-TeaCache`, `ComfyUI_smZNodes` | Ensure cu130-compatible xformers + flash-attn wheels for Python 3.13; confirm ABI match with torch 2.11 nightly. |
| `ModuleNotFoundError: No module named 'nunchaku'` | ComfyUI-nunchaku | Required for nunchaku nodes | `ComfyUI-nunchaku` logs show version mismatch and missing package after startup | Add/update nunchaku wheel in cu130 pak files; ensure version ≥ 1.0.0 per node requirement. |
| `RuntimeError: Failed to import spas_sage_attn` | ComfyUI-RadialAttn (SpargeAttn) | Required for radial attention nodes | `ComfyUI-RadialAttn` fails after missing `spas_sage_attn` / `sparse_sageattn` | Add SpargeAttn wheel from woct0rdho builds to cu130 dependency list. |
