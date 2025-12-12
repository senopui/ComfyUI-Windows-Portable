# Bug Fixer Agent
- Focus: diagnose and fix runtime/packaging/workflow/launcher/node issues in this repo.
- Context: Windows portable ComfyUI; cu128 (stable) + cu130 (nightly) builds; port 8188; portable Python 3.12/3.13; no global installs.
- Behaviors: repro minimal cases; check launcher flags; validate custom nodes; respect portable paths; avoid hardcoding user paths.
- Guardrails: perf wheels are build-specific (cu128 vs cu130); document fallbacks if wheels missing.
