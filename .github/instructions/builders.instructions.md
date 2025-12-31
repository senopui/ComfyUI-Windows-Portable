---
applyTo: "builder*/**"
---

Always follow AGENTS.md guidance (root + scoped AGENTS.md).

# Builder scripts (builder*/)

## Workflow norms
- /plan first for build-system work.
- Fix the **first fatal error** before warnings.
- Provide verification evidence (commands + outputs + CI run links).
- Avoid parallel edits on the same files.

## Sharp edges
- `cu130` is stable; `cu130-nightly` is experimental. Never regress stable intent.
- Optional accelerators are best-effort; never hard-fail CI. Gate + warn + manifest.
- Never allow pip to downgrade torch or pull CPU torch; fail fast or skip/gate.
- Skip flags: only `1/true/yes` means skip; string `"0"` must not skip.
- Diagnostics must use `python_standalone` (not system python); avoid fragile `python -c` quoting.

## Where to look first
- Stage scripts: `stage1.sh` (dependencies), `stage2.sh` (repos/custom nodes), `stage3.sh` (packaging)
- Follow patterns already present in the target builder directory

## Non-breaking rules
- Preserve portability (embedded Python, in-tree tools). No global installs.
- Keep behavior consistent with the existing stage scripts (`stage1.sh`, `stage2.sh`, `stage3.sh`).
- Do not "simplify" by removing best-effort installs; guard failures with warnings as the scripts already do in cu130.

## Shell conventions
- Keep the script's existing strict mode (`set -euo pipefail` or `set -eux`) consistent within each script.
- Don't introduce new repo-wide env assumptions; use the script's existing `workdir=$(pwd)` patterns.

## Git clone rules (match repo reality)
- Custom nodes commonly use shallow clones (`--depth=1 --no-tags --recurse-submodules --shallow-submodules`).
- All builder scripts define a `gcs` helper variable for this pattern in stage2.sh.
- **Do not force `--no-tags` for ComfyUI in stable builds** where the script uses tags to select latest `v*` tag (builder-cu128 does this).

## Pip/requirements rules
- Do not restate or reorder the dependency install sequence in prose.
- Instead: "Follow the exact order already implemented in each `builder*/stage1.sh` (note: `builder/` differs from `builder-cu128/` and `builder-cu130/`, e.g., presence of pakZ)."
- If editing pak files, keep changes minimal and document the reason.

## Validation (reference-only; prefer documenting patterns over modifying scripts)
- Quick test command exists in builder scripts:
  `./python_standalone/python.exe -s -B ComfyUI/main.py --quick-test-for-ci --cpu`
- Workflows also validate by scanning logs for `Traceback`; keep that concept consistent when documenting checks.

## Packaging rules
- Do not change archive naming or split sizing logic; keep the existing `stage3.sh` behavior (7z, BCJ2, and ~2.14GB volumes).
- Models are separated into `models.zip.*` in stage3 scripts; preserve that.
