---
applyTo: ".github/workflows/**"
---

# GitHub Actions workflows (.github/workflows/**)

## Where to look first
- Existing workflow files in `.github/workflows/` for patterns already in use
- Match conventions present in build-cu128.yml, build-cu130.yml, build-cu130-nightly.yml

## Scope/intent
- Workflows must preserve the repo's portability constraints and existing builder stage execution model.

## Shell + working directory conventions (match repo reality)
- Use `shell: bash` explicitly where needed (match the workflows already present in this repo with bash steps on Windows runners).
- Use `working-directory: builder*` and run stages as the workflows already do:
  `bash stage1.sh`, `bash stage2.sh`, `bash stage3.sh`

## Validation patterns (match repo reality)
- Keep the existing "launcher validation" idea:
  - run quick-test with a timeout
  - capture logs
  - fail on `Traceback` detection
- Do not add new third-party actions or caching without explicit justification; document patterns when possible.

## Optional accelerator workflow conventions (cu130-nightly)
- Use the existing gated install steps in `build-cu130-nightly.yml`:
  - `scripts/install_core_attention.ps1` (writes manifest entries)
  - `scripts/install_optional_accel.ps1` (best-effort, gated)
  - `scripts/attempt_install_xformers.ps1` (best-effort, no source builds)
- Missing wheels **must not** fail the workflow; log as `GATED` and continue.
- PowerShell installer steps must capture pip output safely (e.g., `2>&1 | Out-String`) to avoid pipeline/output crashes.
- FlashAttention installs should resolve from PyPI binary-only first, then fall back to AI-windows-whl; keep gated when wheels are unavailable.
- Preserve `accel_manifest.json` upload for visibility.
- Respect `SAGEATTENTION2PP_PACKAGE` (opt-in) and `SKIP_CORE_ATTENTION` (stage1 deferral) environment toggles.
