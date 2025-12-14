# Final QC/QA Report

## 0) Baseline
- Branch: `copilot/final-qc-qa-pass`
- HEAD at start: `907868077adbd2e819698aa1aee5b405496a0654`
- Latest `main` is merged (merge-base with fetched `main` == HEAD).
- Working tree was clean before changes.

## 1) PR Inventory
- Git history merges: PR **#6** (“Merge with main: Sync PR #6 with all improvements from PR #1, #4, and #15”) – adds build workflows, portable builders (cu128, cu130 nightly/stable), launchers, docs, and packaging attachments.
- GitHub CLI inventory: **not available** (GH_TOKEN not set in this environment); rely on git history above.

## 2) Static Validation
- Actionlint: `/tmp/actionlint -shellcheck '' .github/workflows/*.yml` → **PASS** (v1.7.9).
- Workflow logic review (spot-check):
  - Build workflows use `builder*` directories; nightly uses `builder-cu130`, stable cu128 uses `builder-cu128`, general build uses `builder`.
  - Release upload jobs set `contents: write` and draft uploads.
  - `test-build.yml` previously ran stage1/2 only; now extended with QA smoke + workflow validation (see below).
- Version / pin audit (high level):
  - `builder-cu130` (nightly/bleeding-edge): Python 3.13 (latest release fetched via API); PyTorch nightly cu130 (`pak3.txt`); best-effort perf wheels (flash-attn, xformers, triton-windows, natten, nunchaku, spargeattention, bitsandbytes) guarded; ComfyUI requirements from master.
  - `builder` (cu130 stable) : Python 3.13.11 (astral release 20251205); PyTorch cu130 release index; installs ComfyUI requirements from latest tag; includes onnxruntime-gpu nightly feed and transformers temp-fix.
  - `builder-cu128` (stable) : Python 3.12.12 (astral release 20251205); PyTorch cu128 release index; temp transformers fix; SAM3 no-deps pin.
  - Fragile pins: `builder-cu130/pak4.txt` installs OpenCV family (>=4.10.0) with `numpy>=1.26.0,<3`; on Py3.13 pip backtracks into source builds (see CI failure). `builder` and `builder-cu128` also rely on OpenCV wheels on Py3.13/3.12—monitor for wheel availability.
- Windows portability scan:
  - Launchers and ExtraScripts use `%~dp0` roots, prepend local `MinGit` and `python_standalone` to PATH, set HF/Torch caches locally, and avoid absolute user paths.
  - No reliance on system Python observed; installers stay portable.

## 3) CI / Build Status & Issues
- GitHub Actions status (nightly): latest **Build & Upload CUDA 13.0 Nightly Package** run failed in Stage 1 (deps).
  - Cause: OpenCV + numpy resolution on Python 3.13; pip backtracked to `opencv-python-headless-4.5.4.60` which requires `numpy==1.21.2` (no cp313 wheel).
  - Source: run id 20201915566, step “Stage 1 Gathering Dependencies” (build-cu130-nightly).
- Recommended mitigation: in `builder-cu130/pak4.txt` raise numpy floor to a Py3.13 wheel (e.g., `numpy>=2.1.0,<3`) and/or guard OpenCV installs for Py3.13 with `--only-binary` or conditional skip until cp313 wheels are available.
- No other workflows were run in this session.

## 4) Packaging / Structure Verification
- Builders assemble portable layout under `ComfyUI_Windows_portable` with:
  - `python_standalone` (moved during stage2), `MinGit`, `HuggingFaceHub`, `TorchHome`, ExtraScripts launchers, and `ComfyUI` repo with >40 custom nodes cloned via shallow clones.
  - Stage3 (where present) packages into 7z archives (volume splits are handled per script).
- Paths referenced in workflows exist (`builder`, `builder-cu128`, `builder-cu130`).

## 5) Runtime Smoke Tests (new)
- Added `scripts/qa_smoketest_windows.ps1`:
  - CPU headless startup: runs `python_standalone/python.exe -s -B ComfyUI/main.py --windows-standalone-build --cpu --quick-test-for-ci --disable-auto-launch`.
  - Parses log for `Traceback`/import errors; non-zero exit or log errors → failure.
  - CUDA probe prints torch version/availability/device; `-ExpectCuda` flag fails if `torch.cuda.is_available()` is false when GPU mode is expected.
  - Log location: `<portable_root>/qa_smoketest-*.log`.
- CI integration: `.github/workflows/test-build.yml` now runs the CPU smoke test after stage2 (Windows runner, powershell).

## 6) Functional Workflow Fixture (new)
- Added `tests/workflows/minimal_text2img.json` (tiny text-to-image graph: checkpoint loader → CLIP encoders → empty latent → KSampler → VAE decode → SaveImage).
- Added validator `scripts/qa_validate_workflow.py`:
  - Structure checks plus node-availability check via `nodes.py` (ComfyUI) unless `--structure-only` is passed.
  - Example with portable build: `./ComfyUI_Windows_portable/python_standalone/python.exe -s scripts/qa_validate_workflow.py --workflow tests/workflows/minimal_text2img.json --comfyui-root ./ComfyUI_Windows_portable/ComfyUI`
  - CI runs validator in `test-build.yml` after smoke test.

## 7) Dependency Correctness Notes
- Python:
  - Nightly: dynamic latest 3.13.xx (python-build-standalone API).
  - Stable cu130: pinned 3.13.11 (20251205).
  - Stable cu128: pinned 3.12.12 (20251205).
- PyTorch:
  - Nightly cu130 index (`pak3.txt` in `builder-cu130`) — enforces cu130 dev build.
  - Stable cu130 index in `builder/pak3.txt`.
  - Stable cu128 index in `builder-cu128/pak3.txt` (xformers pinned 0.0.33.post2).
- Perf wheels: `builder-cu130` uses best-effort installs with warnings (flash-attn, xformers, sageattention+triton-windows, natten, nunchaku, spargeattention, bitsandbytes). Failures are warned, not fatal.
- Known blocker (unfixed): OpenCV + numpy resolution for Python 3.13 in `builder-cu130/pak4.txt` (source build attempts, no cp313 numpy 1.21.x). Needs a higher numpy floor or guarded OpenCV install.

## 8) CI Additions
- `test-build.yml` now includes:
  - `QA CPU Smoke Test (portable layout)` using `scripts/qa_smoketest_windows.ps1`.
  - `Validate minimal workflow fixture` using `scripts/qa_validate_workflow.py` against assembled portable tree.

## 9) Manual QA (Windows 11 + NVIDIA GPU)
1. Assemble portable build (builder-cu130 for nightly or builder/builder-cu128 for stable).
2. CPU sanity (already scripted in CI):
   ```powershell
   pwsh -File scripts/qa_smoketest_windows.ps1 -PortableRoot "X:\ComfyUI_Windows_portable"
   ```
3. GPU check:
   ```powershell
   pwsh -File scripts/qa_smoketest_windows.ps1 -PortableRoot "X:\ComfyUI_Windows_portable" -ExpectCuda
   ```
   - Fails if `torch.cuda.is_available()` is false; log saved to `qa_smoketest-*.log`.
4. Workflow validation against assembled tree:
   ```powershell
   .\ComfyUI_Windows_portable\python_standalone\python.exe -s scripts/qa_validate_workflow.py `
     --workflow tests/workflows/minimal_text2img.json `
     --comfyui-root .\ComfyUI_Windows_portable\ComfyUI
   ```
5. (Manual) Launchers: run `builder-cu130/attachments/ExtraScripts/run_optimized_fidelity.bat` and `run_maximum_fidelity.bat` to confirm port 8188 + no Tracebacks; verify caches stay under portable root.

## 10) Pass/Fail Summary
- Actionlint: **PASS**
- Workflow definitions present & valid: **PASS**
- New CPU smoke test script added & wired in CI: **PASS**
- Nightly dependency resolution (Py3.13 + OpenCV): **FAIL** (see blocker above)
- Portable path hygiene: **PASS** (launchers use `%~dp0`, local PATH/caches)

## 11) Commands Run This Session
- `git status`, `git log`, `git fetch origin main`
- `npx actionlint` (failed: npm exec unavailable), `npx @wearerequired/actionlint` (404)
- `/tmp/actionlint -shellcheck '' .github/workflows/*.yml`
- `python scripts/qa_validate_workflow.py --structure-only`

## 12) Outstanding Items / Recommendations
- Address Py3.13 + OpenCV + numpy resolver failure in `builder-cu130/pak4.txt` (suggest `numpy>=2.1,<3` and/or conditional OpenCV install or `--only-binary` guard). Re-run nightly workflow after fix.
- Consider similar guard for `builder` (Py3.13.11) if OpenCV wheels for cp313 remain unavailable.
- GH CLI access: supply GH_TOKEN for automated PR inventory in future QC runs.
