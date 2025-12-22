# Nightly Builds Quick Reference

## Quick Start

### What You Get
- **Python 3.13** + **PyTorch Nightly (2.10+)** + **CUDA 13.0**
- Latest xformers, FlashAttention, SageAttention, NATTEN
- ComfyUI master branch (bleeding edge)
- Two specialized launcher modes

### Download
Look for files named: `ComfyUI_Windows_portable_cu130_nightly.7z.*`
- Release tag: `nightly-cu130`
- Updated daily at 02:00 UTC

## Launcher Modes

### Maximum Fidelity Mode
**File:** `ExtraScripts/run_maximum_fidelity.bat`

```
Flags: --disable-xformers --disable-smart-memory
Use for: Production renders, quality-critical work
Trade-off: Slower, but maximum precision
```

### Optimized Fidelity Mode  
**File:** `ExtraScripts/run_optimized_fidelity.bat`

```
Flags: (none - uses default optimizations)
Use for: Interactive workflows, general use
Trade-off: Faster, optimized performance
```

## Key Differences from Stable Builds

| Feature | Stable Builds | Nightly Builds |
|---------|--------------|----------------|
| Python | 3.12/3.13 | 3.13 |
| PyTorch | Stable | Nightly (2.10+) |
| CUDA | 12.8/13.0 | 13.0 |
| ComfyUI | Tagged release | Master branch |
| xformers | Pinned version | Latest |
| FlashAttention | No | Yes (optional) |
| SageAttention | No | Yes (optional) |
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
2. **Stage 2:** Clone ComfyUI master + custom nodes + run CPU test
3. **Validation:** Test both launcher modes, check for errors
4. **Stage 3:** Create split archives
5. **Release:** Upload as draft/prerelease

## Error Handling

The build handles package failures gracefully:
```
Warning: Failed to install [package] (may be incompatible with Python 3.13 / PyTorch nightly)
```

This is expected. The build continues with available packages.

## More Information

See `docs/nightly-builds.adoc` for comprehensive documentation.
