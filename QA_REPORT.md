# Final QA Pass

## Baseline
- Branch: `copilot/final-qc-qa-pass-again`
- HEAD: `a154229`
- Status before changes: clean working tree (`git status -sb` showed no changes).

## PR Inventory
- Source A (git history merges/squash): PRs #1, #4, #5, #6, #7, #8, #9, #10, #11, #12, #13, #14, #15, #18, #19, #20 observed in merge commits and tags.
- Source B (`gh pr list --state merged --repo senopui/ComfyUI-Windows-Portable`): same set surfaced (latest merged: #20 copilot-setup workflow; #19 upload-artifact v6; #18 Copilot instructions refactor; #15 CUDA13 build fix; #4/#5 nightly/stable build consolidation; earlier consolidation PRs).
- Intent summary (high level):
  - PRs #4/#5/#15: establish CUDA 13 nightly build (builder-cu130) with dynamic Python 3.13 and guarded performance wheels; fix torch verification and xformers handling.
  - PR #5/#6/#7: consolidate stable builder updates and documentation.
  - PR #8–#14: launcher, workflow, and CI consistency fixes; argparse/name cleanup; agent configuration.
  - PR #18–#20: Copilot instruction refactors and setup workflow; dependency bumps (upload-artifact v6).

## Static Validation
- Actionlint: `$(go env GOPATH)/bin/actionlint` → **pass** (no workflow lint issues).
- Workflow/env review: workflows keep `shell: bash` on Windows where stage scripts run; release upload uses draft + overwrite; permissions scoped to contents/packages PR read.
- Version/pin audit:
  - Stable builder (`builder`): Python 3.13.11 standalone (fixed URL), PyTorch cu130 stable index, transformers temp-fix, ORT CUDA13 nightly (pre index), ffmpeg/aria2/ninja binaries.
  - CUDA13 nightly (`builder-cu130`): Python 3.13 latest release (API lookup), torch/vision/audio from nightly cu130, guarded installs for flash-attn/xformers/triton-windows/natten/etc. (best-effort), cp312 wheels for dlib/insightface (fragile on cp313), cupy cuda13x→12x fallback.
  - CUDA12.8 (`builder-cu128`): Python 3.12.12, torch cu130 stable index, transformers temp-fix, SAM3 no-deps.
  - Fragile spots: direct wheel URLs (onnxruntime-gpu nightly feed, cp312-only dlib/insightface on cp313), ai-windows-whl extras may be missing; recommend treating as best-effort (already guarded in cu130) and keeping recovery reinstall for torch if downgraded.
- Windows portability spot-check: launchers under `builder/attachments` use `%~dp0`-relative paths and bundled `python_standalone`; no absolute user paths found in sampled scripts (`RUN_Launcher.bat`). Stage scripts keep portable binaries (MinGit/ffmpeg/aria2) and avoid system Python.

## Build Verification (reasoning)
- Required artifacts per stage scripts: `ComfyUI_Windows_portable/` containing `python_standalone/`, `ComfyUI/` repo with `custom_nodes`, launchers and `attachments/ExtraScripts`, and bundled binaries (MinGit, aria2c, ffmpeg, ninja). Stage2 already runs `--quick-test-for-ci --cpu` after installs and cleans logs/configs.
- Path validation: workflow steps reference `builder` and `builder/ComfyUI_Windows_portable/...` which exist post-stage2; added validation steps use those same paths.
- Not executed in-session (build is heavy); run `bash stage1.sh && bash stage2.sh` in `builder/` (and `stage3.sh` for packaging) to produce `.7z` splits (~2.14GB volumes).

## Runtime Smoke Tests
- Added `scripts/qa_smoketest_windows.ps1`:
  - Default root: repo root; auto-detects `ComfyUI_Windows_portable` (top-level or under `builder/`).
  - Runs torch CUDA probe (prints version/availability/device). If `-ExpectGpu`, fails when `torch.cuda.is_available()` is false.
  - Runs `ComfyUI/main.py --quick-test-for-ci` in CPU or GPU mode, writes log to `<portable>/qa_smoketest.log`, fails on non-zero exit or if `Traceback`/`ImportError` detected.
- CI: `.github/workflows/test-build.yml` now runs `qa_validate_workflow.py` then `qa_smoketest_windows.ps1 -Mode cpu` after stage2 on `windows-latest`.
- Manual GPU check (self-hosted with NVIDIA): `./scripts/qa_smoketest_windows.ps1 -Mode gpu -ExpectGpu` from repo root after stage2 (or extracted package).

## Workflow Fixture Validation
- Added `tests/workflows/minimal_text2img.json` (tiny base-node graph: CheckpointLoaderSimple, CLIPTextEncode x2, EmptyLatentImage, KSampler, VAEDecode, SaveImage).
- Added `scripts/qa_validate_workflow.py` to ensure workflow JSON parses and required base nodes exist; also asserts `ComfyUI/` present under the portable root. Command: `builder/ComfyUI_Windows_portable/python_standalone/python.exe -s -B scripts/qa_validate_workflow.py --root "$PWD"`.

## Dependency Audit Notes
- Stable path (builder/cu128): fixed Python standalone URLs; PyTorch from stable cu130 index; transformers temp-fix; cp312/313 differences noted; binaries bundled.
- Nightly path (cu130): nightly torch cu130 + guarded performance wheels; torch version revalidated after xformers; fallbacks for cupy; best-effort installs already non-fatal. Raised numpy floor in `pak4.txt` to `numpy>=2.1.0,<3` to avoid OpenCV resolver backtracking on Python 3.13.
- Recommendations: keep treating missing performance wheels as warnings; monitor ORT CUDA13 nightly feed and cp313 wheel availability for dlib/insightface; retain torch recovery reinstall guard.

## Status Matrix
| Category | Result | Notes |
| --- | --- | --- |
| Baseline recorded | ✅ | Branch/HEAD/status captured |
| PR inventory | ✅ | git merges + `gh pr list` cross-checked |
| Workflow lint | ✅ | `actionlint` clean |
| Portability/pin review | ✅ | Relative launchers; fragile pins documented |
| Build/package verification | ⚠️ | Not executed in-session (heavy); stage scripts unchanged |
| Runtime smoke (CPU) | ✅ planned | CI step added; script provided (not run locally) |
| Runtime smoke (GPU) | 🔲 manual | Requires self-hosted CUDA; use `-ExpectGpu` |
| Workflow fixture validation | ✅ | Script + fixture added; runs in CI |

## Commands to Run
- Workflow lint (already run): `$(go env GOPATH)/bin/actionlint`
- Build/package (manual): `(cd builder && bash stage1.sh && bash stage2.sh && bash stage3.sh)`
- CPU smoke: `./scripts/qa_smoketest_windows.ps1 -Mode cpu`
- GPU smoke: `./scripts/qa_smoketest_windows.ps1 -Mode gpu -ExpectGpu`
- Workflow validation: `builder/ComfyUI_Windows_portable/python_standalone/python.exe -s -B scripts/qa_validate_workflow.py --root "$PWD"`

## Logs
- Smoke test log: `<portable>/qa_smoketest.log` (portable root autodetected).
- Stage scripts produce logs in `ComfyUI_Windows_portable/*.log` (cleaned at end of stage2).

## Manual QA (Windows 11 + NVIDIA)
1) In PowerShell, run builder stages (or extract packaged artifact).
2) CPU quick check: `.\scripts\qa_smoketest_windows.ps1 -Mode cpu`.
3) GPU validation: `.\scripts\qa_smoketest_windows.ps1 -Mode gpu -ExpectGpu` (fails fast if CUDA unavailable).
4) Optional workflow sanity: `.\builder\ComfyUI_Windows_portable\python_standalone\python.exe -s -B scripts/qa_validate_workflow.py --root "$PWD"`.
5) Launch via packaged launcher (e.g., `RUN_Launcher.bat`) to verify UI starts; watch for `Traceback` in console/log.

## Open Issues / Blockers
- Heavy build/packaging not re-run in this QA pass (resource/time). CI smoke covers CPU path; GPU verification requires self-hosted runner or manual Windows machine with CUDA 13 drivers.
- Nightly build should be re-run to confirm OpenCV/numpy resolution on Python 3.13 after raising the numpy floor in `builder-cu130/pak4.txt`.
- cp313 wheel gaps for dlib/insightface and performance wheels remain best-effort; failures are logged but non-fatal in nightly builder.
