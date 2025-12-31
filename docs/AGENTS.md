# docs Scoped Instructions

## Documentation norms
- Keep guidance aligned with build behavior and CI workflows.
- Keep wording compact; avoid duplicating long explanations from root guidance.
- Docs-only PRs: do **not** edit build scripts or workflow YAML.

## Policy reminders to document consistently
- `cu130` is stable; `cu130-nightly` is experimental.
- Optional accelerators are best-effort; never hard-fail CI (warn + gate + manifest).
- Never allow pip to downgrade torch or pull CPU torch.
- Preserve port 8188 and ComfyUI API compatibility notes.
- PowerShell sharp edges: `${var}:` or format strings, validate JSON, keep stdout clean.
- Skip flags: only `1/true/yes` means skip; string `"0"` must not skip.
- Diagnostics must use `python_standalone` with safe quoting (stdin here-strings).

## Verification evidence (for doc changes)
- Reference exact commands and CI log locations that prove the guidance.

## Review guidelines
- **P0**: CI red, stable build broken, torch downgraded/CPU torch pulled, segfault, or interactive prompt hang.
- **P1**: nightly-only regression, optional accelerator missing but gated, manifest missing/invalid, or validation skipped.
