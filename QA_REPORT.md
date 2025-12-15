# Final QC/QA Pass (post-merge)

## 0) Baseline
- Branch: `work`
- HEAD: `c547b5a841e7eb7586bd57b790e0efd7704ffc24` (merge of PR #22)
- Remote status: no git remotes configured; unable to confirm sync with upstream main.
- Pre-change state: clean working tree (`git status -sb`).

## 1) PR Inventory (git history)
_GitHub CLI unavailable in environment; inventory derived from `git log --merges`._

| PR | Intent / Key Files | Expected Behavior |
| --- | --- | --- |
| #22 | QA follow-up: updated `builder-cu130/pak4.txt`, `builder-cu130/stage1.sh`, and refreshed QA report. | Nightly cu130 stack installs without Unicode console errors. |
| #6 | Added `build-cu128.yml` workflow. | Introduces CUDA 12.8 build path. |
| #4 | Introduced cu130 nightly workflow scaffolding (Python 3.13/CUDA 13). | Enables nightly build pipeline. |
| #1 | Added nightly build workflow entry in `README.adoc`. | Documents new pipeline. |
| #15 | Hardened cu130 torch/xformers verification in `pak4.txt` and `stage1.sh`. | Prevents torch downgrades; asserts cu130 nightly. |
| #16 | Cleaned Copilot agent syntax; removed path-specific agent files. | Centralizes repo agent config. |
| #14 | Batch launcher path fixes across builders. | Launchers respect portable paths/flags. |
| #5 | Consolidated nightly/stable builder improvements. | Aligns logging and guarded perf wheel installs. |
| #7 | Massive consolidation: new cu130 builder scripts, force-update tools, workflows, and docs. | Establishes primary packaging flow and attachments. |
| #12 | Standardized argparse/flag ordering for cu130 launcher. | Launchers accept consistent CLI flags. |
| #13 | Added Copilot agent presets and trimmed instructions. | Repository guidance for contributors. |
| #10 | Launcher consistency for cu128 variant. | CPU/GPU launch scripts share flags. |
| #11 | Launcher validation ordering + naming fixes. | Ensures nightly package naming and validation order. |
| #8 | Aligned launchers/docs/workflows for cu130 nightly. | Consistent launcher arguments and docs. |
| #9 | Further cu130 workflow/doc alignment. | Keeps docs and launcher flags in sync. |

_(Merge metadata references: `git log --oneline --merges` and `git show --stat -1 <sha>` for each PR.)_

## 2) Static Validation
- **GitHub Actions lint**: `actionlint` against `.github/workflows/*.yml` → **PASS**.
- **Version/pin audit (stable vs nightly)**:
  - Nightly cu130 pipeline fetches latest Python 3.13 standalone dynamically and installs torch from nightly cu130 index, with guarded perf wheels (flash-attn, xformers, sageattention, triton-windows, natten, nunchaku, spargeattention) and recovery checks to keep `torch` on cu130 nightly.【F:builder-cu130/stage1.sh†L13-L173】【F:builder-cu130/pak3.txt†L1-L4】
  - Stable/cu130 workflow pins a specific Python build (3.13.11+20251205) and torch from the cu130 release index, with temporary ORT nightly and transformers pin noted as workarounds.【F:builder/stage1.sh†L13-L48】【F:builder/pak3.txt†L1-L6】
  - Fragile pins: multiple direct wheel URLs for cp312-only packages (dlib, insightface), AI-windows-whl perf wheels, and nightly ORT feed. Documented as best-effort; recommend conditional install guards and fallbacks to CPU-only behavior when wheels absent.【F:builder-cu130/stage1.sh†L112-L140】
- **Windows portability scan**:
  - Launchers predominantly use `%~dp0`-relative paths and local Python/MinGit. `run_cpu.bat` in ExtraScripts still lacks an `@echo off` preamble but otherwise uses portable paths (low risk).【F:builder-cu130/attachments/ExtraScripts/run_cpu.bat†L1-L8】

## 3) Build Verification (structure & CI hooks)
- Packaging expectations: embedded `python_standalone`, `ComfyUI`, `custom_nodes`, `extensions`, `ExtraScripts`, `MinGit`, and bundled `ffmpeg.exe` under `python_standalone/Scripts`.
- Added `scripts/qa_verify_portable_layout.ps1` to assert the above layout (fails on missing components).【F:scripts/qa_verify_portable_layout.ps1†L1-L60】
- CI update: `test-build.yml` now runs the layout verifier on GitHub-hosted Windows runners after Stage 2, before smoketests.【F:.github/workflows/test-build.yml†L9-L32】

## 4) Runtime Smoke Tests
- `scripts/qa_smoketest_windows.ps1` (CPU): headless `--quick-test-for-ci --cpu`, parses logs for import errors/tracebacks, and optionally enforces CUDA availability when `-ExpectCuda` is set.【F:scripts/qa_smoketest_windows.ps1†L1-L99】
- CUDA probe prints torch version/availability/device; GPU failures raise clear errors when GPU mode is expected.【F:scripts/qa_smoketest_windows.ps1†L69-L86】
- CI step executes the CPU smoketest on windows-latest runners (`test-build.yml`). GPU validation remains manual/self-hosted due to hardware limits.【F:.github/workflows/test-build.yml†L21-L32】

## 5) Functional Workflow Fixture
- Fixture: `tests/workflows/minimal_text2img.json` (Checkpoint → TextEncode ± → EmptyLatent → KSampler → VAE → SaveImage).【F:tests/workflows/minimal_text2img.json†L1-L43】
- Validator: `scripts/qa_validate_workflow.py` checks JSON structure and (optionally) node registry; `--structure-only` passes in this environment.【F:scripts/qa_validate_workflow.py†L1-L86】
- Command run: `python scripts/qa_validate_workflow.py --structure-only` → PASS.

## 6) Dependency Correctness Audit
- **Python**: cu130 nightly dynamically tracks latest 3.13.x; stable/cu130 pins 3.13.11. Both use python-build-standalone (portable, no system Python reliance).【F:builder-cu130/stage1.sh†L13-L35】【F:builder/stage1.sh†L13-L18】
- **PyTorch**: nightly uses cu130 nightly index; stable uses cu130 release index. Recovery check re-installs nightly if xformers downgrades torch.【F:builder-cu130/pak3.txt†L1-L4】【F:builder/pak3.txt†L1-L6】【F:builder-cu130/stage1.sh†L42-L73】
- **Performance wheels**: flash-attn/xformers/sageattention/triton-windows/natten/nunchaku/spargeattention installed best-effort from curated sources; CI should allow failures without breaking CPU path.【F:builder-cu130/stage1.sh†L53-L99】
- **CUDA/ORT**: cu130 nightly includes cupy-cuda13x fallback to cuda12x; stable path temporarily consumes ORT CUDA13 nightly feed then reinstalls final wheel.【F:builder-cu130/stage1.sh†L120-L123】【F:builder/stage1.sh†L31-L35】
- **Known risks**: cp312 wheels on Python 3.13 (dlib/insightface) likely fail; documented best-effort. Recommend conditional skips for CPU-only runs or replacing with cp313 builds when available.【F:builder-cu130/stage1.sh†L112-L118】

## 7) Results & Manual QA Guidance
- **Commands executed**: `actionlint`; `python scripts/qa_validate_workflow.py --structure-only`.
- **CI additions**: layout verifier + CPU smoketest on `windows-latest`; GPU smoketest reserved for manual/self-hosted runners.
- **Manual QA (Windows 11 + NVIDIA)**:
  1. Build via `workflow_dispatch` for `Test Build (No Upload)`. Confirm layout verifier and CPU smoketest steps pass.
  2. From packaged root, run `scripts/qa_smoketest_windows.ps1 -ExpectCuda` to assert GPU availability and check logs.
  3. Optionally run `scripts/qa_validate_workflow.py --comfyui-root <portable>/ComfyUI` after assembly to ensure nodes are present.

### Pass/Fail Summary
| Category | Status | Notes |
| --- | --- | --- |
| Git status baseline | PASS | Clean before changes. |
| PR inventory | PASS | Git-only inventory (gh CLI unavailable). |
| Actionlint | PASS | No workflow lint errors. |
| Portable layout check | ADDED | New verifier script + CI step. |
| CPU smoketest | PASS (script + CI hook) | GPU path marked manual. |
| Workflow validator | PASS (`--structure-only`) | Node-registry validation requires assembled ComfyUI. |
| Dependency audit | WARNINGS | cp312 wheels on Python 3.13; best-effort perf wheels/nighly ORT noted. |
