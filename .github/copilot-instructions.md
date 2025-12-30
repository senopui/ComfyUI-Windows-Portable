# ComfyUI Windows Portable — Copilot Instructions

## Repo at a glance
- Windows 11 **portable** distribution of ComfyUI (embedded `python_standalone/`, portable tools in-repo).
- Build directories: `builder/`, `builder-cu128/`, `builder-cu130/`.
- Default web UI port: **8188** (required by character selector app compatibility).
- Optional accelerator gating (cu130-nightly) writes `accel_manifest.json` and runtime preflight can disable dependent custom nodes.

## Universal rules (apply everywhere)
1) **Portability first**: no global installs, no absolute machine paths, no "install system-wide" guidance.
2) **Relative paths only**:
   - Batch: use `%~dp0` (already ends with `\`).
   - Bash: prefer paths rooted from a known working dir (scripts already use `workdir=$(pwd)` patterns).
3) **Don't change default behavior**: do not change port 8188, do not add `--listen`, do not change launcher semantics unless explicitly requested.
4) **No secrets**: never commit tokens/keys; avoid echoing secrets in logs.
5) **Small PRs**: one logical change; minimal diff; explain root cause + verification.
6) **Validation mindset**: when changing anything that affects launch/build, reference the repo's existing validation steps (quick-test / Traceback checks used in builder scripts/workflows).
7) **Optional accelerators are best-effort**: missing wheels must not fail builds; keep manifest + warnings for visibility.

## Path-specific guidance
See `.github/instructions/*.instructions.md` for rules scoped by `applyTo`.

## Agent profiles
See `.github/agents/*.agent.md` for role playbooks and tool limits.
