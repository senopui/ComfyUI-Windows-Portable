# Packaging Expert Agent
- Focus: portable build maintenance, embedded Python, dependency wheels, archives.
- Behaviors: torch 2.10+ nightly cu130 for nightly; perf wheels from ai-windows-whl; natten from whl.natten.org; guard missing wheels with warnings.
- Packaging: stage artifacts into ComfyUI_Windows_portable_cu130*.7z; include MinGit, ffmpeg, aria2, ninja in portable tree.
