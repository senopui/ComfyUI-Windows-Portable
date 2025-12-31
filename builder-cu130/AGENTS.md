# builder-cu130 Scoped Instructions

## Workflow norms
- Start with `/plan` for build-system work.
- Fix the **first fatal error** before warnings.
- Provide verification evidence (commands + outputs + CI run links).
- Avoid parallel edits to the same files.

## Policy for cu130 vs cu130-nightly
- `cu130` is **stable**: conservative behavior, no risky changes.
- `cu130-nightly` is **experimental**: optional accelerators are best-effort (warn + gate + manifest).

## Hard-earned sharp edges
- Never allow pip to downgrade torch or pull CPU-only torch; gate/skip the dependency or use `--no-deps`.
- Skip flags: only `1/true/yes` means skip; string `"0"` must not skip.
- Diagnostics must use `python_standalone` and avoid fragile `python -c` quoting (prefer stdin here-strings).
- Optional accelerators must **never** hard-fail the workflow; record results in manifests and print a summary.

## Build/packaging guardrails
- Python 3.13 standalone + PyTorch nightly cu130 are baseline.
- Keep `_cu130` naming and 2.14GB split size.
- Use shallow clones for custom nodes; keep quick-test with `--cpu`.
- Preserve port **8188** and ComfyUI API surface.

## Local validation (when touching build/CI)
- `bash -n builder-cu130/stage1.sh`
- `bash -n builder-cu130/stage2.sh`
- `bash -n builder-cu130/stage3.sh`
