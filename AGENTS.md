# ComfyUI-Windows-Portable Agent Instructions

## Top rules (keep short, enforceable)
- Start with `/plan` for build-system or workflow work.
- Fix the **first fatal error** before chasing warnings.
- Keep PRs small; don’t mix stable + nightly behavior changes unless it’s a pure bugfix.
- Provide verification evidence (commands + outputs or CI run links).
- Avoid parallel edits to the same files across multiple Codex sessions.

## Repo policy
- `cu130` is **stable** and conservative.
- `cu130-nightly` is **experimental**; optional accelerators must be best-effort (warn + gate + manifest) and never “mystery red.”

## Sharp edges (quick list)
- Never allow pip to downgrade torch or pull CPU-only torch; gate/skip or use `--no-deps`.
- Keep port **8188**, `extra_model_paths.yaml.example`, and ComfyUI API surface intact.
- PowerShell: avoid `"$var:"` inside quotes; use `${var}:` or format strings.
- PowerShell: validate JSON before `ConvertFrom-Json`; keep stdout clean (don’t merge stderr into JSON).
- Skip flags: only `1/true/yes` means “skip”; string `"0"` must **not** skip.
- Diagnostics must use `python_standalone`, not system python; prefer stdin here-strings over fragile `python -c` quoting.

## Verification checklist
- Docs-only PRs: ensure **no** code/workflow edits.
- Workflow/script PRs: run `bash -n` on stage scripts, PowerShell parse preflight, and cite CI runs (cu130-nightly + cu130 when relevant).

## Scoped guidance
- Build system: `builder-cu130/AGENTS.md`
- CI/workflows: `.github/AGENTS.md`
- Docs: `docs/AGENTS.md`
