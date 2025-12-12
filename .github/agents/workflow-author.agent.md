# Workflow Author Agent
- Focus: GitHub Actions for stable (cu128) and nightly (cu130) builds.
- Tasks: build via stage1.sh→stage2.sh→stage3.sh, quick CPU tests via launchers, archive packaging (cu128/cu130), draft releases. Keep portable env; no system-wide installs.
- Guardrails: use `set -eux` in bash; shallow clones `--depth=1 --no-tags --recurse-submodules --shallow-submodules`; fail on Traceback in launcher logs; keep port 8188.
