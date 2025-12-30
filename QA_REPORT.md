# QA_REPORT (Final)
- Date: 2025-12-30
- Repo / branch: /workspace/ComfyUI-Windows-Portable @ fix/numpy-py313-no-sdist-20251230
- Commit SHA: 4f9590f5324c44ce0b52af3883e7718b66bb26ee
- Scope: cu130 + cu130-nightly

## Executive Summary
- Overall status: **BLOCKED (CI PENDING)**
- Root cause (from CI logs): `pak7.txt` pinned NumPy 1.x, so pip built numpy-1.26.4 from source on Python 3.13, uninstalled NumPy 2.x, then torch/numpy imports segfaulted (exit code 139).
- Fix applied: NumPy pins split by Python version in `pak7.txt`, `pip` forced to use NumPy wheels only for pak7, and a post-pak7 NumPy import sanity check now fails fast with a clear error.
- CI runs have not been executed in this environment; URLs and status are pending.

## Evidence Bundle
- `qa_evidence/20251230/`
  - `00_context.md` (repo/branch/SHA + git log)
  - `01_local_checks.md` (local static checks output)
  - `02_ci_runs.md` (CI run log evidence and outcomes)
  - `03_ci_log_signatures.md` (required signature list; scan results)
  - `04_artifacts.md` (artifact verification status)
  - `05_docs_audit.md` (doc/instruction file audit + updates)

## Test Matrix
| Check | Evidence | Status |
| --- | --- | --- |
| Local static checks (yaml, shell, python compileall) | Not run in this change | NOT RUN |
| CI: cu130 workflow run (URL, status) | Pending | NOT RUN |
| CI: cu130-nightly workflow run (URL, status) | Pending | NOT RUN |
| Artifact verification (downloaded? contents verified?) | Not run in this change | NOT RUN |
| Regression signature scan (log search) | Not run in this change | NOT RUN |

## Key Findings
### Fixed items
- Guarded NumPy selection for Python 3.13 to prevent NumPy 1.x sdist installs, and added a NumPy import sanity check to fail fast if wheels are missing or broken.

### 2025-12-30 Attention stack install stability update
- What failed: the core attention install step crashed because PowerShell output handling dropped/blocked pip output, causing the step to exit unexpectedly.
- What changed: PowerShell now captures pip output safely, FlashAttention wheel resolution is explicit (PyPI binary-only → AI-windows-whl fallback) with gated failures, and Cozy VCS URLs were corrected.
- How to verify: trigger the cu130-nightly workflow run, then run the local smoke test `pwsh -File scripts/qa_smoketest_windows.ps1`.

### Gated/optional items
- Optional accelerator and VCS installs remain best-effort and are not allowed to fail the build.

### Open Issues
- **CI validation pending** — cu130 and cu130-nightly runs must be triggered and linked here before release readiness can be confirmed.

## Release Readiness Checklist
- [ ] cu130 green
- [ ] cu130-nightly green OR explicitly gated
- [ ] no mystery reds
- [x] docs updated
- [x] QA_REPORT accurate
