# .github Scoped Instructions

## Workflow norms
- Always start with `/plan` for build-system work.
- Provide verification evidence: commands + outputs + CI run links.
- Avoid parallel threads touching the same files.

## Sharp edges
- `cu130` is stable; `cu130-nightly` is experimental. Never regress stable intent.
- Optional accelerators are best-effort; never hard-fail CI. Gate + warn + write manifests.
- Never allow pip to downgrade torch or pull CPU torch; fail fast or skip/gate the package.

## PowerShell robustness
- Capture stdout/stderr (`2>&1 | Out-String`) and log it.
- Validate JSON before writing manifests; fail fast on invalid JSON.

## CI validation checklist
- Quick-test (CPU) log section shows no `Traceback`.
- Manifests uploaded:
  - `builder-cu130/accel_manifest.json`
  - `builder-cu130/vcs_optional_manifest.json`
- Log locations: GitHub Actions run → job logs for `Stage 1`, `Stage 2`, `Validation`, `Stage 3`, `Upload artifacts`.

## Review guidelines
- **P0**: CI red, stable build broken, torch downgraded/CPU torch pulled, segfault, or interactive prompt hang.
- **P1**: nightly-only regression, optional accelerator missing but gated, manifest missing/invalid, or validation skipped.
