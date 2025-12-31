# .github Scoped Instructions

## Workflow norms
- Start with `/plan` for build/workflow work.
- Fix the **first fatal error** before chasing warnings.
- Provide verification evidence: commands + outputs + CI run links.
- Avoid parallel edits to the same files.

## Policy guardrails
- `cu130` is stable; `cu130-nightly` is experimental.
- Optional accelerators are best-effort; never hard-fail CI. Gate + warn + manifest.
- Never allow pip to downgrade torch or pull CPU torch; fail fast or skip/gate.

## PowerShell sharp edges (must follow)
- Never write `"$var:"` inside double quotes; use `${var}:` or format strings.
- Never `ConvertFrom-Json` on unknown output; validate JSON first.
- Keep stdout clean for JSON parsing (don’t merge stderr into JSON output).
- Skip flags: only `1/true/yes` means “skip”; string `"0"` must not skip.
- Diagnostics must use `python_standalone` (not system python) and avoid fragile `python -c` quoting (prefer stdin here-strings).

## CI validation checklist
- Quick-test (CPU) log section shows no `Traceback`.
- Manifests uploaded:
  - `builder-cu130/accel_manifest.json`
  - `builder-cu130/vcs_optional_manifest.json`
- Log locations: GitHub Actions run → job logs for `Stage 1`, `Stage 2`, `Validation`, `Stage 3`, `Upload artifacts`.

## Review guidelines
- **P0**: CI red, stable build broken, torch downgraded/CPU torch pulled, segfault, or interactive prompt hang.
- **P1**: nightly-only regression, optional accelerator missing but gated, manifest missing/invalid, or validation skipped.
