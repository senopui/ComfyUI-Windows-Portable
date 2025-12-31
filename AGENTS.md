# Agent Guidance (Repo Root)

This repo builds **Windows portable ComfyUI** with two tracks:
- **cu130** = STABLE (conservative, must not regress)
- **cu130-nightly** = NIGHTLY (experimental: Python 3.13+, Torch nightly/dev, CUDA 13)

## Non-negotiables
1) **Start with `/plan`** for any change that touches build scripts, workflows, or dependency logic.
2) **Small PRs** > mega PRs. Fix the **first fatal error** before chasing warnings.
3) **Evidence-based output only**:
   - If you say “PASS”, include command output or CI run links.
   - Don’t claim tests you didn’t run.
4) **Stable safety**:
   - If a change is risky, it must be **nightly-only**.
   - Stable must not silently change torch/cuda/python behavior.
5) **Optional accelerators must never hard-fail CI**:
   - install attempt → validate import → if fail: **warn + gate + record in manifest** → continue.
6) **Never let pip downgrade torch or pull CPU-only torch**:
   - if a package forces it, install with `--no-deps` or gate/skip it.

## Repo “sharp edges” (common failure modes)
- **PowerShell strings**: never write `"$var:"` inside double quotes.
  - use `"${var}:"` or `("{0}:" -f $var)`
- **Skip flags**: `"0"` must mean “do NOT skip”.
  - only `1/true/yes` should mean “skip”
- **Diagnostics** must use **builder python_standalone**, not system Python.
- **JSON parsing**: don’t `ConvertFrom-Json` on unknown output; validate first and keep stdout clean (don’t merge stderr into JSON).

## Where the real rules live
- Build/deps/scripts: `builder-cu130/AGENTS.md`
- GitHub Actions workflows & CI: `.github/AGENTS.md`
- Docs-only changes: `docs/AGENTS.md`

## Quick verification checklist (minimum bar)
- Scripts:
  - `bash -n builder-cu130/stage1.sh builder-cu130/stage2.sh builder-cu130/stage3.sh`
  - PowerShell parse check (Windows runner or local pwsh):
    - `[scriptblock]::Create((Get-Content -Raw <file.ps1>)) | Out-Null`
- CI:
  - If nightly-related: link a passing **cu130-nightly** run
  - If stable-impacting: link a passing **cu130** run

## When in doubt
Prefer **gating** (warn + manifest) over “red CI for optional stuff”.