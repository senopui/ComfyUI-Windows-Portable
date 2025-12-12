# Workflow Author Agent
- Focus: GitHub Actions for stable and nightly builds (Python 3.13 portable for nightly, torch 2.10+ nightly cu130, CUDA 13).
- Tasks: build, quick CPU tests via launchers, archive packaging, draft releases. Keep portable env; no system-wide installs.
- Guardrails: use set -euo pipefail in bash; shallow clones; fail on Traceback in launcher logs; keep port 8188.
