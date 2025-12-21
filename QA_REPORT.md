# QA Report

## Upstream Sync
- Upstream: `https://github.com/YanWenKun/ComfyUI-Windows-Portable` (default branch `main`)
- Before sync SHA: `e906265c2f45cf1470549a8f14438da225d65f05`
- After sync SHA: `ea7bc5ca56bb0fc3223634767c89a4d3e3a25fc9`
- Notable upstream changes: workflow/test-build improvements and builder updates; no breaking dependency changes noted.

## CI Failure Evidence (CUDA 13.0 Nightly)
| Run Date (UTC) | Run ID | Failing Step | Error Excerpt | Failure Class |
| --- | --- | --- | --- | --- |
| 2025-12-21 | [20403953035](https://github.com/senopui/ComfyUI-Windows-Portable/actions/runs/20403953035) | Stage 1 Gathering Dependencies | `UnicodeEncodeError: 'charmap' codec can't encode character '\u2713'` during torch nightly verification | Encoding/locale |
| 2025-12-20 | [20388197571](https://github.com/senopui/ComfyUI-Windows-Portable/actions/runs/20388197571) | Stage 1 Gathering Dependencies | `UnicodeEncodeError: ... '\\u2713'` | Encoding/locale |
| 2025-12-19 | [20358633634](https://github.com/senopui/ComfyUI-Windows-Portable/actions/runs/20358633634) | Stage 1 Gathering Dependencies | `UnicodeEncodeError: ... '\\u2713'` | Encoding/locale |

Root cause: cp1252 encoding on Windows runners could not emit the checkmark (✓) used in torch cu130 nightly assertion logging.

## Fixes & Hardening
- Replaced the non-ASCII checkmark in `builder-cu130/stage1.sh` torch cu130 nightly assertion output with plain ASCII text to avoid cp1252 encoding failures.
- Added artifact layout validation to the CUDA 13 nightly workflow to fail fast if the packaged portable tree is incomplete.

## New QA Assets
- `scripts/qa_smoketest_windows.ps1`: CPU headless smoke test; logs to `<portable>/logs/qa-smoketest.log`; fails on Traceback/import/DLL errors.
- Optional: set `QA_DISABLE_WINDOWS_STANDALONE=1` to skip the `--windows-standalone-build` flag if running against a non-portable install.
- `scripts/qa_validate_workflow.py`: Validates node availability for `tests/workflows/minimal_text2img.json`.
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

## Validation Status
- actionlint: **run** (v1.7.9) – no issues.
- QA scripts (smoketest, workflow validator): **not run** in this environment because ComfyUI portable root is not present. Commands to execute after build:
  - `pwsh ./scripts/qa_smoketest_windows.ps1`
  - `python ./scripts/qa_validate_workflow.py`
- CodeQL: **not run** (no analyzable language changes in this iteration).

## Manual QA (Windows 11 + NVIDIA, guidance)
1. Run `scripts/qa_smoketest_windows.ps1` (expects portable root with python_standalone and ComfyUI).
2. Launch `run_nvidia_gpu.bat` and confirm web UI loads on port 8188; run a simple workflow (e.g., minimal_text2img.json with a valid checkpoint).
3. Check `logs/` for absence of Tracebacks.

## Remaining Risks
- GPU inference not exercised in CI (Windows runners lack CUDA); manual GPU validation still required.
- Artifact validation only checks presence of key files, not full runtime.
- QA scripts not yet executed here; run post-build on Windows with assembled portable tree to confirm runtime.
