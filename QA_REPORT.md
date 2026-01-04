# QA_REPORT (Final)
- Date: 2026-01-03
- Repo / branch: senopui/ComfyUI-Windows-Portable @ ce58b7fd581fc1386301c1a09a18233d4b54986f (cu130-nightly)
- Scope: cu130-nightly (Python 3.13+, CUDA 13.x, PyTorch nightly/dev)
- Sources of truth:
  - Evidence bundle: https://drive.google.com/uc?export=download&id=14ZwuPSAjrQ2xa8bHR6VdQTxQW1x5JQKU
  - GitHub Actions run: https://github.com/senopui/ComfyUI-Windows-Portable/actions/runs/20671487273
  - accel_manifest.json (from evidence bundle)
  - local_comfyui_startup.log (from evidence bundle)

## Executive Summary
- Overall status: **✅ VERIFIED (cu130-nightly build succeeded)**
- Evidence: successful CI package build + local startup log + accelerator manifest from the evidence bundle.
- Known limitations: optional accelerators are gated due to missing wheels for Python 3.13/nightly; runtime nodes depending on them load in degraded mode.

## ✅ Completed / Verified
### cu130-nightly run summary
- Workflow: build-cu130-nightly.yml (Build & Upload CUDA 13.0 Nightly Package)
- Run: https://github.com/senopui/ComfyUI-Windows-Portable/actions/runs/20671487273
- Commit: ce58b7fd581fc1386301c1a09a18233d4b54986f
- Python: 3.13.11 (python-build-standalone tag 20251217)
- CUDA: 13.0 (torch reports `cuda 13.0`)
- PyTorch: 2.11.0.dev20260102+cu130

## CI Warnings/Errors (successful run)
### P2 — optional accelerator missing but correctly gated
- Unsupported Python 3.13 for AI-windows-whl filtering (warning emitted during optional accel resolution).
- GATED: flash-attn / flash_attn_3 (no cp313 wheels; source build not feasible on Windows runner).
- GATED: sageattention2 / sageattention2pp (unsupported or missing wheels).
- GATED: sageattention (missing triton).
- GATED: nunchaku (no compatible release wheel).
- GATED: no matching wheel for cp313 torch>=2.10.0 cu130 (optional install skipped).
- Optional accelerator install encountered an unexpected error (`if` not recognized as cmdlet) — did not fail CI but indicates a script issue in optional install flow.

### FYI — harmless warnings / noise
- GITHUB_TOKEN not set; GitHub API calls may be rate-limited.
- Python build SHA256 lookup missing for latest attempt; fallback to pinned Python build.
- CUDA device query warnings on CI runner (expected on non-GPU runner).

## Accelerator Status (accel_manifest.json)
Short-field rule: values are the first ~120 characters with newlines stripped; no stack traces. Evidence source is `/tmp/evidence/accel_manifest.json`.

Summary: `triton-windows` installed successfully. All other listed accelerators were gated or failed due to Python 3.13 wheel gaps or missing dependencies.

| name | requested | success | version | source | gated | gate_reason (short) | error_if_any (short) |
| --- | --- | --- | --- | --- | --- | --- | --- |
| sageattention2pp | — | False | — | unsupported | — | unsupported (SAGEATTENTION2PP_PACKAGE not set) | unsupported (SAGEATTENTION2PP_PACKAGE not set) |
| flash-attn | source_spec=flash-attn; pattern=flash[_-]attn | False | — | none | True | unsupported python version 3.13 | pip exit 1: / unsupported python version 3.13 / Source build not feasible on Windows runner. |
| flash_attn_3 | source_spec=flash-attn-3; pattern=flash[_-]attn[_-]?3 | False | — | none | True | unsupported python version 3.13 | pip exit 1: / unsupported python version 3.13 / flash_attn_3 wheel unavailable for this build. |
| sageattention | source_spec=sageattention; pattern=sageattention | False | — | pypi | True | D:\a\ComfyUI-Windows-Portable\ComfyUI-Windows-Portable\builder-cu130\python_standalone\Lib\site-packages\torch\cuda\__in | D:\a\ComfyUI-Windows-Portable\ComfyUI-Windows-Portable\builder-cu130\python_standalone\Lib\site-packages\torch\cuda\__in |
| sageattention2 | source_spec=sageattention2; pattern=sageattention2 | False | — | none | True | unsupported python version 3.13 | pip exit 1: / unsupported python version 3.13 / Source build not feasible on Windows runner. |
| triton-windows | source_spec=triton-windows<3.6; pattern=triton[_-]windows | True | 3.5.1.post23 | pypi | False | — | — |

### Action Plan (top 5 blockers from manifest)
1. FlashAttention (flash-attn): enable cp313/cu130 wheel or keep gated with explicit release tracking.
2. FlashAttention 3 (flash_attn_3): publish cp313/cu130 wheel; keep gated until available.
3. SageAttention: resolve missing `triton` dependency or gate cleanly on cp313.
4. SageAttention2: publish cp313 wheel or keep gated; confirm Windows source build feasibility.
5. SageAttention2++: set `SAGEATTENTION2PP_PACKAGE` when supported; otherwise keep gated explicitly.

## Runtime Status (local_comfyui_startup.log)
| Missing import / issue | Classification | Recommended handling |
| --- | --- | --- |
| Nunchaku package missing (`Package 'nunchaku' not found`) and multiple Nunchaku nodes failed to import | Expected (gated accelerator) | Keep gated; re-enable when cp313 wheel becomes available or ship optional wheel. |
| ComfyUI-RadialAttn import failed | Unexpected | Patch node to degrade gracefully or bundle missing dependency. |
| AnimateDiffEvo: “No motion models found” | Expected (asset missing) | Document required model download or ship optional model pack. |

## 🔧 Open Work Items (prioritized)
1. **P1 – Optional accel script error** | Owner: CI/workflow | Scope: `scripts/install_optional_accel.ps1` | Acceptance: no “`if` not recognized as cmdlet” warning; optional installs continue to gate cleanly.
2. **P1 – RadialAttn import failure** | Owner: node patch | Scope: `ComfyUI-RadialAttn` custom node | Acceptance: node imports cleanly or self-disables with a clear message.
3. **P2 – Nunchaku wheels (cp313/cu130)** | Owner: packaging | Scope: optional wheel resolver + manifest | Acceptance: cp313 wheel available or node gated with explicit message in manifest and runtime log.
4. **P2 – Sageattention stack** | Owner: packaging | Scope: optional accelerator install + manifest | Acceptance: when wheels exist, install succeeds; otherwise keep gated with clear reason.
5. **P2 – flash-attn / flash_attn_3 wheels** | Owner: packaging | Scope: optional accelerator install | Acceptance: detect wheel availability for cp313/cu130 or continue gating without error.
6. **P3 – Python standalone SHA256 lookup warnings** | Owner: CI/workflow | Scope: Python resolver in CI | Acceptance: avoid “latest attempt missing SHA256” warning when pinned build is used.
7. **P3 – AnimateDiffEvo model availability** | Owner: docs/packaging | Scope: documentation or optional model pack | Acceptance: users have a clear path to obtain required motion models.
