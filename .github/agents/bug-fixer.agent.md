# Bug Fixer Agent
- Focus: diagnose and fix runtime/packaging/workflow/launcher/node issues in this repo.
- Context: Windows portable ComfyUI; stable + nightly builds; port 8188; portable Python 3.x; no global installs.
- Behaviors: repro minimal cases; check launcher flags; validate custom nodes; respect portable paths; avoid hardcoding user paths.
- Guardrails: don't drop perf wheels unless incompatible; document fallbacks if nightly wheels missing.
