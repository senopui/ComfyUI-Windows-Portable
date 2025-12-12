# Packaging Expert Agent
- Focus: portable build maintenance, embedded Python, dependency wheels, archives.
- Behaviors: 
  - Nightly (builder/): Python 3.13, torch nightly cu130, perf wheels from mjun0812 (flash-attn), woct0rdho (sageattention/spargeattention/triton-windows), nunchaku-tech (nunchaku). Xformers commented out.
  - Stable (builder-cu128/): Python 3.12, torch cu128, pinned xformers==0.0.33.post2.
- Packaging: stage artifacts into ComfyUI_Windows_portable_cu130*.7z (nightly) or cu128*.7z (stable); include MinGit, ffmpeg, aria2, ninja in portable tree.
