---
type: agent
name: Workflow Author
description: Maintain GitHub Actions workflows for stable and nightly builds with portable Python, PyTorch, and CUDA support
---

# Workflow Author Agent

## Focus
GitHub Actions workflows for stable and nightly builds.

## Build Configurations
### Stable Build
- Conservative approach
- Pinned dependencies for reliability
- Standard PyTorch with CUDA support

### Nightly Build
- Python 3.13 portable
- PyTorch 2.10+ nightly cu130
- CUDA 13.0 support
- Bleeding-edge performance wheels

## Tasks
- Build portable distributions
- Run quick CPU tests via launchers
- Create archive packages (7z split volumes)
- Generate draft releases
- Validate with `--quick-test-for-ci --cpu`

## Guardrails
- Use `set -euo pipefail` in bash scripts
- Use shallow clones for repositories
- Fail on Traceback in launcher logs
- Keep port 8188 default
- Maintain portable environment (no system-wide installs)
- Keep embedded Python and in-tree binaries
- Test launchers before packaging
