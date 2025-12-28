---
applyTo: "**/*.bat"
---

# Launcher batch files (batch launchers)

## Where to look first
- Existing launcher patterns in `builder-cu130/attachments/ExtraScripts/*.bat`
- Main launchers: `run_nvidia_gpu.bat`, `run_cpu.bat`, and specialized variants

## Portability rules
- Use `%~dp0` for portable-relative paths; avoid introducing new absolute paths.
- Legacy launchers may use system paths (e.g., `"C:\Program Files\Git\bin\bash.exe"`); when possible, prefer in-repo tools like MinGit.
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
- Main supported launchers:
  - `run_nvidia_gpu.bat`
  - `run_cpu.bat`
