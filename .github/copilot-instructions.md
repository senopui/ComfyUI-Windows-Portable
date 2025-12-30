# ComfyUI Windows Portable — Copilot Instructions

## Repo at a glance
- Windows 11 **portable** distribution of ComfyUI (embedded `python_standalone/`, portable tools in-repo).
- Build directories: `builder/`, `builder-cu128/`, `builder-cu130/`.
- Default web UI port: **8188** (required by character selector app compatibility).
- Optional accelerator gating (cu130-nightly) writes `accel_manifest.json` and runtime preflight can disable dependent custom nodes.

## Universal rules (apply everywhere)
1) **/plan first for build-system work**.
2) **Verification evidence required**: commands + outputs + CI run links.
3) **No parallel edits on the same files**.
4) **Portability first**: no global installs, no absolute machine paths, no "install system-wide" guidance.
5) **Relative paths only**:
   - Batch: use `%~dp0` (already ends with `\`).
   - Bash: prefer paths rooted from a known working dir (scripts already use `workdir=$(pwd)` patterns).
6) **Don't change default behavior**: do not change port 8188, do not add `--listen`, do not change launcher semantics unless explicitly requested.
7) **Sharp edges**:
   - `cu130` is stable; `cu130-nightly` is experimental. Never regress stable intent.
   - Optional accelerators are best-effort; never hard-fail CI (gate + warn + manifest).
   - Never allow pip to downgrade torch or pull CPU torch; fail fast or skip/gate.
8) **PowerShell robustness**: capture stdout/stderr (`2>&1 | Out-String`) and validate JSON before writing manifests.

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
