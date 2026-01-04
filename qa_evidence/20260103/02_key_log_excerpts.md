# Key log excerpts (high-signal)
Source: logs_53435201468/0_build_upload.txt

## Python + torch CUDA verification
```
2026-01-03T03:26:04.7839156Z Python 3.13.11
2026-01-03T03:27:12.7525990Z torch 2.11.0.dev20260102+cu130 cuda 13.0
```

## Optional accelerator gating highlights
```
2026-01-03T03:26:39.1727862Z WARNING: GATED: sageattention2pp unsupported (SAGEATTENTION2PP_PACKAGE not set)
2026-01-03T03:26:44.0459174Z WARNING: GATED: flash-attn not available (pip exit 1:  | unsupported python version 3.13 | Source build not feasible on Windows runner.). Marked as gated in accel_manifest.json.
2026-01-03T03:26:47.3746743Z WARNING: GATED: flash_attn_3 not available (pip exit 1:  | unsupported python version 3.13 | flash_attn_3 wheel unavailable for this build.). Marked as gated in accel_manifest.json.
2026-01-03T03:26:53.4934079Z WARNING: GATED: sageattention not available (D:\a\ComfyUI-Windows-Portable\ComfyUI-Windows-Portable\builder-cu130\python_standalone\Lib\site-packages\torch\cuda\__init__.py:61: FutureWarning: The pynvml package is deprecated. Please install nvidia-ml-py instead. If you did not install pynvml directly, please report this to the maintainers of the package that installed pynvml for you.
2026-01-03T03:26:56.6937301Z WARNING: GATED: sageattention2 not available (pip exit 1:  | unsupported python version 3.13 | Source build not feasible on Windows runner.). Marked as gated in accel_manifest.json.
2026-01-03T03:27:17.5424322Z WARNING: GATED: nunchaku not available (GitHub release wheel unavailable | unsupported python version 3.13 | pip exited with code 1)
2026-01-03T03:27:27.1758608Z WARNING: GATED: no matching wheel for cp313 torch>=2.10.0 cu130. Skipping install.
```
