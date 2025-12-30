# QA_REPORT (Final)
- Date: 2025-12-30
- Repo / branch: /workspace/ComfyUI-Windows-Portable @ qa/final-qc-20251230
- Commit SHA: df510a2ddf102a638d7d5783263028b211d8e4da
- Scope: cu130 + cu130-nightly

## Executive Summary
- Overall status: **FAIL (CI FAILURES)**
- Verified: local static checks (git status, workflow listing, YAML parse attempt, shell syntax, Python compileall).
- CI logs supplied externally show both cu130 and cu130-nightly builds failed during stage1 when `pip` attempted to clone `cozy-comfy` and GitHub prompted for credentials in a non-interactive context.
- Regression signature scan executed on the supplied CI logs; none of the required signatures were observed.
- Artifacts were not produced due to the stage1 failures.

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
| Local static checks (yaml, shell, python compileall) | `qa_evidence/20251230/01_local_checks.md` (CI URL: N/A — local check) | PASS |
| CI: cu130 workflow run (URL, status) | `qa_evidence/20251230/02_ci_runs.md` (log bundle: `logs_53236406321.zip`) | FAIL |
| CI: cu130-nightly workflow run (URL, status) | `qa_evidence/20251230/02_ci_runs.md` (log bundle: `logs_53236403191.zip`) | FAIL |
| Artifact verification (downloaded? contents verified?) | `qa_evidence/20251230/04_artifacts.md` | NOT RUN (build failed before packaging) |
| Regression signature scan (log search) | `qa_evidence/20251230/03_ci_log_signatures.md` | PASS (no required signatures found) |

## Key Findings
### Fixed items
- None in this QA pass (documentation refresh only).

### Gated/optional items
- Documentation now explicitly calls out best-effort optional accelerator installs and manifest/preflight gating for nightly builds. (See `docs/nightly-builds.adoc` and `qa_evidence/20251230/05_docs_audit.md`.)
- The supplied CI logs show `flash-attn` and `spargeattention` wheels were unavailable for cp313/torch-nightly/cu130 and were skipped with warnings (best-effort behavior).

### Open Issues
- **Severity: High** — CI builds fail in stage1 due to `cozy-comfy` git clone prompting for credentials.
  - **Symptom:** `fatal: Cannot prompt because user interactivity has been disabled` followed by `fatal: could not read Username for 'https://github.com'`.
  - **Where observed:** `qa_evidence/20251230/02_ci_runs.md` (both cu130 and cu130-nightly logs).
  - **Likely cause:** `pip` attempts to clone a GitHub dependency that now requires authentication or is rate-limited for anonymous access.
  - **Suggested follow-up PR scope:** Update dependency acquisition to avoid interactive Git prompts (e.g., replace with a vetted wheel or ensure public access) and re-run the CI workflows.

## Release Readiness Checklist
- [ ] cu130 green
- [ ] cu130-nightly green OR explicitly gated
- [ ] no mystery reds
- [x] docs updated
- [x] QA_REPORT accurate
