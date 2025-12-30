# docs Scoped Instructions

## Documentation norms
- Keep guidance aligned with build behavior and CI workflows.
- Keep wording compact; avoid duplicating long explanations from root guidance.

## Sharp edges to document consistently
- `cu130` is stable; `cu130-nightly` is experimental.
- Optional accelerators are best-effort; never hard-fail CI.
- Never allow pip to downgrade torch or pull CPU torch; fail fast or skip/gate.
- Preserve port 8188 and ComfyUI API compatibility notes.

## Verification evidence (for doc changes)
- Reference exact commands and CI log locations that prove the guidance.

## Review guidelines
- **P0**: CI red, stable build broken, torch downgraded/CPU torch pulled, segfault, or interactive prompt hang.
- **P1**: nightly-only regression, optional accelerator missing but gated, manifest missing/invalid, or validation skipped.
