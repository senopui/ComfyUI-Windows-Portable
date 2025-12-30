# CI Log Signature Scan
Scanned logs:
- `logs_53236406321.zip` → `0_build_upload.txt`
- `logs_53236403191.zip` → `0_build_upload.txt`

## Required signatures
A) curl: (22) — **NOT FOUND**
A) 403 — **NOT FOUND** (only appears as part of timestamps; no HTTP 403 errors observed)
A) JSONDecodeError — **NOT FOUND**
B) torch was downgraded — **NOT FOUND**
B) 2.9.1+cpu — **NOT FOUND**
C) WARNING[XFORMERS]: xFormers can't load — **NOT FOUND**
C) ImportError: DLL load failed while importing _C — **NOT FOUND**
C) flash_attn_3 — **NOT FOUND**
C) Failed to import diffusers — **NOT FOUND**
D) requires nunchaku >= v1.0.0 — **NOT FOUND**
D) ModuleNotFoundError: No module named 'nunchaku' — **NOT FOUND**
E) No module named 'spas_sage_attn' — **NOT FOUND**
E) No module named 'sparse_sageattn' — **NOT FOUND**
E) Failed to import spas_sage_attn — **NOT FOUND**

## Other noteworthy log findings
- Both logs show stage1 failure when `pip` attempted to clone `cozy_comfy`/`cozy_comfyui` from GitHub and the process could not prompt for credentials.
- `flash-attn` and `spargeattention` wheels were unavailable for the cp313/torch-nightly/cu130 combination (skipped with warnings).
