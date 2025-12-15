---
type: agent
name: Bug Fixer
description: Diagnose and fix runtime, packaging, workflow, launcher, and custom node issues in this Windows portable ComfyUI repository
tools: ["read","search","edit","execute"]
infer: true
---

# Bug Fixer Agent

## Where to look first
- Builder stage scripts (`stage1.sh`, `stage2.sh`, `stage3.sh`) for build issues
- Launcher `.bat` files in `builder*/attachments/ExtraScripts/` for runtime issues
- Workflow files in `.github/workflows/` for CI/CD issues

## Focus
Diagnose and fix runtime/packaging/workflow/launcher/node issues in this repo.

## Context
- Windows portable ComfyUI distribution
- Stable + nightly builds
- Default port: 8188
- Portable Python 3.x (no global installs)
- Two build flavors: stable (conservative) and nightly (bleeding-edge with Python 3.13, PyTorch 2.10+ cu130)

## Commands (repo-real only)
- Quick test validation (from builder scripts):
  `./python_standalone/python.exe -s -B ComfyUI/main.py --quick-test-for-ci --cpu`
- Traceback detection: workflows scan logs for `Traceback` to fail builds

## Boundaries
- Port 8188 is non-negotiable (character selector app compatibility)
- No absolute paths; use `%~dp0` in batch files, `workdir=$(pwd)` patterns in bash
- No global installs; keep embedded Python and in-tree tools
- Don't drop perf wheels unless proven incompatible
- Use `set -euo pipefail` in bash scripts (match existing style)

## Definition of done
1. Minimal repro steps documented
2. Minimal diff (change only what's broken)
3. Validation: reference quick-test or Traceback check pattern

## Good output example
```diff
- ./python_standalone/python.exe ComfyUI/main.py
+ .\python_standalone\python.exe -s -B ComfyUI\main.py --windows-standalone-build
```
(Fixed: missing portable invocation flags)
