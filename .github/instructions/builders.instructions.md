---
applyTo: "builder*/**"
---

# Builder scripts (builder*/)

## Non-breaking rules
- Preserve portability (embedded Python, in-tree tools). No global installs.
- Keep behavior consistent with the existing stage scripts (`stage1.sh`, `stage2.sh`, `stage3.sh`).
- Do not "simplify" by removing best-effort installs; guard failures with warnings as the scripts already do in cu130.

## Shell conventions
- Keep the script's existing strict mode (`set -euo pipefail` or `set -eux`) consistent within each script.
- Don't introduce new repo-wide env assumptions; use the script's existing `workdir=$(pwd)` patterns.

## Git clone rules (match repo reality)
- Custom nodes commonly use shallow clones (`--depth=1 --no-tags --recurse-submodules --shallow-submodules`) via the existing `gcs` pattern.
- **Do not force `--no-tags` for ComfyUI in stable builds** where the script uses tags to select latest `v*` tag (builder-cu128 does this).

## Pip/requirements rules
- Do not restate or reorder the dependency install sequence in prose.
- Instead: "Follow the exact order already implemented in each `builder*/stage1.sh` (note: `builder/` differs from `builder-cu128/` and `builder-cu130/`, e.g., presence of pakZ)."
- If you edit pak files, keep the change minimal and document why in the PR (but this PR should NOT edit pak files).

## Validation (reference-only; don't change scripts in this PR)
- Quick test command exists in builder scripts:
  `./python_standalone/python.exe -s -B ComfyUI/main.py --quick-test-for-ci --cpu`
- Workflows also validate by scanning logs for `Traceback`; keep that concept consistent when documenting checks.

## Packaging rules
- Do not change archive naming or split sizing logic; keep the existing `stage3.sh` behavior (7z, BCJ2, and ~2.14GB volumes).
- Models are separated into `models.zip.*` in stage3 scripts; preserve that.
