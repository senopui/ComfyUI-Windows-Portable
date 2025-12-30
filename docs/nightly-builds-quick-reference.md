# Nightly Builds Quick Reference

## Quick Start

### What You Get
- **Python 3.13** + **PyTorch nightly (2.10+ cu130)** + **CUDA 13.0**
- Best-effort performance stack with **explicit gating** (FlashAttention, SageAttention, NATTEN, SpargeAttn, Nunchaku, bitsandbytes)
- Optional xformers install attempt (no source builds; skips when unavailable)
- ComfyUI master branch (bleeding edge)
- Accelerator manifest + runtime preflight (`accel_manifest.json`) for transparency and safe node gating

### Download
Look for files named: `ComfyUI_Windows_portable_cu130_nightly.7z.*`
- Release tag: `nightly-cu130`
- Updated daily at 02:00 UTC

## Key Differences from Stable Builds

| Feature | Stable Builds | Nightly Builds |
|---------|--------------|----------------|
| Python | 3.12/3.13 | 3.13 |
| PyTorch | Stable | Nightly (2.10+) |
| CUDA | 12.8/13.0 | 13.0 |
| ComfyUI | Tagged release | Master branch |
| xformers | Not installed by default | Best-effort install attempt |
| Optional accelerators | Stage1 best-effort only | Manifested + gated + preflight |
| Stability | High | Experimental |

## Important Notes

⚠️ **Nightly builds are experimental**
- Less stable than tagged releases
- Some packages may fail to install (expected)
- Best for testing and development
- Keep stable builds for production

✅ **Compatibility maintained**
- Port 8188 (standard)
- ASAR=false
- Works with external tools

✅ **Optional accelerator policy**
- Missing wheels **must not fail** builds; they are gated with warnings.
- Results are recorded in `builder-cu130/accel_manifest.json` and copied into the portable tree at `ComfyUI/user/default/accel_manifest.json`.
- Launchers run `scripts/preflight_accel.py` to re-check availability and disable dependent custom nodes (e.g., `ComfyUI-nunchaku`, `ComfyUI-RadialAttn`) when required backends are missing.

## When to Use

### ✅ Good For
- Testing new features
- Performance benchmarking  
- Early adoption of optimizations
- Contributing to development

### ❌ Not Recommended For
- Production workflows
- Mission-critical projects
- Beginners learning ComfyUI
- Stable environment needs

## Build Process

Automated via GitHub Actions:
1. **Stage 1:** Install Python 3.13 + PyTorch nightly + bleeding-edge packages
2. **Core attention stack:** `install_core_attention.ps1` (nightly only; gated)
3. **Optional accelerators:** `install_optional_accel.ps1` (nightly only; gated, writes manifest)
4. **xformers attempt:** `attempt_install_xformers.ps1` (nightly only; gated)
5. **Stage 2:** Clone ComfyUI master + custom nodes + run CPU test + accelerator preflight
6. **Validation:** Run quick test, check for errors
7. **Stage 3:** Create split archives
8. **Release:** Upload as draft/prerelease

## Error Handling

The build handles package failures gracefully:
```
Warning: Failed to install [package] (may be incompatible with Python 3.13 / PyTorch nightly)
```

This is expected. The build continues with available packages.

## Environment Toggles (Nightly)
- `SKIP_CORE_ATTENTION=1` (used by workflow to defer core attention installs to PowerShell step)
- `SAGEATTENTION2PP_PACKAGE` (optional package spec; enables SageAttention2++ install in `install_core_attention.ps1`)
- Availability flags emitted in CI (`NUNCHAKU_AVAILABLE`, `SPARGEATTN_AVAILABLE`, `NATTEN_AVAILABLE`, `BITSANDBYTES_AVAILABLE`) for downstream reporting

## More Information

See `docs/nightly-builds.adoc` for comprehensive documentation.
