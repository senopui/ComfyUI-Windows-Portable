# ComfyUI Windows Portable — Copilot Instructions

## Repo at a glance
- Windows 11 **portable** distribution of ComfyUI (embedded `python_standalone/`, portable tools in-repo).
- Build directories: `builder/`, `builder-cu128/`, `builder-cu130/`.
- Default web UI port: **8188** (required by character selector app compatibility).
- Optional accelerator gating (cu130-nightly) writes `accel_manifest.json` and runtime preflight can disable dependent custom nodes.

## Universal rules (apply everywhere)
1) **/plan first** for build-system or workflow work.
2) **Fix the first fatal error** before chasing warnings.
3) **Verification evidence required**: commands + outputs + CI run links.
4) **No parallel edits** on the same files.
5) **Portability first**: no global installs, no absolute machine paths, no "install system-wide" guidance.
6) **Relative paths only**:
   - Batch: use `%~dp0` (already ends with `\`).
   - Bash: prefer paths rooted from a known working dir (scripts already use `workdir=$(pwd)` patterns).
7) **Don't change default behavior**: do not change port 8188, do not add `--listen`, do not change launcher semantics unless explicitly requested.
8) **Repo policy**:
   - `cu130` is stable; `cu130-nightly` is experimental.
   - Optional accelerators are best-effort (warn + gate + manifest).
   - Never allow pip to downgrade torch or pull CPU torch; fail fast or skip/gate.
9) **PowerShell sharp edges**:
   - Never write `"$var:"` inside double quotes; use `${var}:` or format strings.
   - Never `ConvertFrom-Json` on unknown output; validate JSON first and keep stdout clean.
   - Skip flags: only `1/true/yes` means skip; string `"0"` must not skip.
   - Diagnostics must use `python_standalone`, avoid fragile `python -c` quoting (prefer stdin here-strings).

## Validation checklist (short)
- Quick-test (CPU) in logs shows no `Traceback`.
- Manifests uploaded: `builder-cu130/accel_manifest.json`, `builder-cu130/vcs_optional_manifest.json`.
- CI log locations: Actions run → Stage 1/2/Validation/Stage 3/Upload artifacts.

## Review guidelines
- **P0**: CI red, stable build broken, torch downgraded/CPU torch pulled, segfault, interactive prompt hang.
- **P1**: nightly-only regression, optional accelerator missing but gated, manifest missing/invalid, validation skipped.

## Path-specific guidance
See `.github/instructions/*.instructions.md` for rules scoped by `applyTo`.

## Agent profiles
See `.github/agents/*.agent.md` for role playbooks and tool limits.
