---
applyTo: "builder*/attachments/**/*.bat"
---

# Launcher batch files (builder*/attachments/**/*.bat)

## Portability rules
- Use `%~dp0` for portable-relative paths (never absolute paths).
- Use `setlocal` / `endlocal`.
- Keep the embedded Python invocation style used in this repo:
  `.\python_standalone\python.exe -s -B <entrypoint> ...`

## Environment conventions (match repo reality)
- PATH additions commonly include:
  `set PATH=%PATH%;%~dp0MinGit\cmd;%~dp0python_standalone\Scripts`
- Cache/asset folders commonly use `%~dp0...`:
  `HF_HUB_CACHE`, `TORCH_HOME`, `PYTHONPYCACHEPREFIX`

## Behavior boundaries
- Do NOT change default port **8188**.
- Do NOT add `--listen` or change networking defaults.
- Keep user-editable flags grouped in `EXTRA_ARGS` (pattern used in `builder-cu130/attachments/ExtraScripts/*.bat`).

## Known launcher variants
- In `builder-cu130/attachments/ExtraScripts/` the repo contains:
  - `run_maximum_fidelity.bat` (EXTRA_ARGS disables xformers/smart-memory/flash-attn)
  - `run_optimized_fidelity.bat` (EXTRA_ARGS defaults to `--disable-auto-launch`)
Document these patterns; don't "normalize" them away.
