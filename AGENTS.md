# ComfyUI-Windows-Portable Agent Instructions

## Workflow norms
- Always start with `/plan` for build-system work.
- Always provide verification evidence (commands + outputs + CI run links).
- Avoid parallel threads touching the same files.

## Sharp edges (never break)
- `cu130` is **stable**; `cu130-nightly` is **experimental**. Never regress stable intent.
- Optional accelerators are best-effort; never hard-fail CI. Gate + warn + write manifest(s).
- Never allow pip to downgrade torch or pull CPU torch; fail fast or skip/gate the package.
- Preserve port **8188**, `extra_model_paths.yaml.example`, and ComfyUI API surface.

## Build/packaging guardrails (concise)
- Python 3.13 standalone + PyTorch nightly cu130 are baseline.
- Keep `_cu130` naming and 2.14GB split size.
- Use shallow clones for custom nodes; keep quick-test with `--cpu`.

## PowerShell robustness
- Capture stdout/stderr (`2>&1 | Out-String`) and log it.
- Validate JSON before writing manifests; fail fast on invalid JSON.
- Avoid interactive prompts; non-interactive installs only.

## Testing/validation checklist (local + CI evidence)
- Local checks (when touching build/CI):
  - `bash -n builder-cu130/stage1.sh`
  - `bash -n builder-cu130/stage2.sh`
  - `bash -n builder-cu130/stage3.sh`
  - `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/build-cu130-nightly.yml'))"` (requires PyYAML; if unavailable, note as not run)
- CI evidence: link the GitHub Actions run and cite log sections for Stage 1/2/3, quick-test, and manifest upload.

## Review guidelines
- **P0**: CI red, stable build broken, torch downgraded/CPU torch pulled, segfault, or interactive prompt hang.
- **P1**: nightly-only regression, optional accelerator missing but gated, manifest missing/invalid, or validation skipped.

## Scoped instructions
- `.github/AGENTS.md` for CI/workflow details.
- `docs/AGENTS.md` for documentation guidance.
