# QA_REPORT (Final)
- Date: 2026-01-01
- Repo / branch: senopui/ComfyUI-Windows-Portable @ 540e25f521b6e0f59f1312f445bbc25371dc774d (cu130-nightly)
- Scope: cu130-nightly (Python 3.13+, CUDA 13.0+, PyTorch nightly)
- Sources of truth:
  - Successful run: https://github.com/senopui/ComfyUI-Windows-Portable/actions/runs/20641030620
  - accel-manifest.json artifact (hash: sha256:ec2f213352edf41a64f5877fa0e633bc062ec18cbc6a09529b086415583c80c3)

## Executive Summary
- Overall status: **✅ VERIFIED (cu130-nightly build succeeded)**
- Evidence: run completed successfully for the nightly CUDA 13.0 workflow (see run link above).

## ✅ Completed / Verified
### cu130-nightly run summary
- Workflow: Build & Upload CUDA 13.0 Nightly Package
- Run: https://github.com/senopui/ComfyUI-Windows-Portable/actions/runs/20641030620
- Commit: 540e25f521b6e0f59f1312f445bbc25371dc774d
- Build outcome: succeeded (job duration 28m 47s)
- Python: 3.13 (from “Resolve latest Python 3.13 standalone build” step)
- CUDA: 13.0 (from workflow name)
- PyTorch: nightly (exact version not visible without run logs/artifacts in this environment)

## ⚠️ Gated / Expected Limitations
- Optional accelerators are best-effort and must remain gated; failures are expected if nightly wheels are unavailable.

## Accelerator Status (accel-manifest.json)
> accel-manifest.json is the authoritative source for accelerator gating and install outcomes.
> The artifact is present for the run (hash listed above), but its contents could not be retrieved in this environment
> due to unauthenticated artifact download restrictions.

| Accelerator | Status | Source | Reason | Notes |
| --- | --- | --- | --- | --- |
| (pending) | unknown | accel-manifest.json | Artifact contents not accessible here | Download the artifact from the run to populate this table. |

## 🔧 Open (Non-blocking Follow-ups)
- Populate the accelerator status table by downloading accel-manifest.json from the linked run.

