# Agent Profile: ComfyUI-Windows-Portable Build Agent

## Goals

The primary goal is to maintain a nightly/bleeding-edge Windows portable package for ComfyUI that:

1. **Uses latest stable stack**
   - Python 3.13 from python-build-standalone
   - PyTorch nightly builds with CUDA 13.0
   - Latest performance optimizations

2. **Includes performance wheels**
   - FlashAttention (mjun0812 prebuild wheels)
   - xformers (when available for cu130)
   - SageAttention+triton-windows (woct0rdho builds)
   - NATTEN (curated AI-windows-whl)
   - Nunchaku (nunchaku-tech)

3. **Maintains compatibility**
   - Keep port 8188 as default
   - Preserve extra_model_paths.yaml.example
   - Don't change ComfyUI API surface
   - Support character_select_stand_alone_app_test

4. **Ensures reliability**
   - Quick test validation during build
   - CPU launcher testing
   - No Traceback errors in tests
   - Clean packaging with proper naming

## Behaviors

### Dependency Management
- **Minimal pinning**: Only pin versions when absolutely necessary
- **Nightly builds**: Prefer PyTorch nightly from cu130 index
- **Performance first**: Always install performance wheels (FlashAttention, SageAttention, etc.)
- **Curated sources**: Use trusted wheel sources (mjun0812, woct0rdho, nunchaku-tech)

### Build Process
1. **Stage 1 - Python Setup**
   - Download Python 3.13 standalone build
   - Install pip, wheel, setuptools
   - Install PyTorch nightly from cu130 index
   - Install performance wheels from pak8.txt
   - Install all dependencies in correct order (pak2-pak8, pakY)
   - Log versions with `pip list`

2. **Stage 2 - Assembly**
   - Clone ComfyUI from master (no tag reset)
   - Shallow clone all custom nodes (`--depth=1 --no-tags`)
   - Copy attachments (launchers, configs)
   - Run quick test with CPU: `--quick-test-for-ci --cpu`
   - Fail on any Traceback errors

3. **Stage 3 - Packaging**
   - Name packages with cu130 suffix: `ComfyUI_Windows_portable_cu130.7z.*`
   - Separate models into models.zip.*
   - Use 7z with proper compression settings
   - Split at 2140000000 bytes for GitHub limits

### Testing Strategy
- **Quick test**: Run during Stage 2 with `--quick-test-for-ci --cpu`
- **CPU launcher validation**: Ensure no Traceback in output
- **Log validation**: Check for missing dependencies or errors
- **Version verification**: Log all package versions

### Launcher Management
- **Preserve launchers**: Don't modify working launchers
- **PATH configuration**: Prepend portable Git to PATH
- **run_maximum_fidelity.bat**: Use `--disable-xformers --disable-smart-memory`
- **run_optimized_fidelity.bat**: Use defaults (xformers/FlashAttention enabled)

### Code Practices
- **Bash scripts**: Always use `set -euo pipefail` or `set -eux`
- **Batch files**: Use `%~dp0` for directory navigation, `setlocal`/`endlocal`
- **Git operations**: Use `git --no-pager` in CI, shallow clones for repos
- **Error handling**: Fail fast on errors, validate outputs

## Constraints

### Security
- **No secrets**: Never commit tokens, passwords, or sensitive data
- **No hardcoded credentials**: Use environment variables for auth
- **Validate inputs**: Check user inputs in launchers and scripts
- **Secure defaults**: Don't expose unnecessary services or ports

### API Stability
- **Port 8188**: Never change default port
- **ComfyUI API**: Don't modify ComfyUI's API surface
- **extra_model_paths.yaml.example**: Keep unchanged for compatibility
- **Backward compatibility**: Package structure must support upgrades

### Build Configuration
- **Keep --asar=false note**: Document where applicable
- **cu130 naming**: Always use `_cu130` suffix in package names
- **Split sizes**: Maintain 2140000000 byte split size
- **Draft releases**: Always upload to draft, never directly to release

### Performance
- **Don't skip optimizations**: Always install FlashAttention, SageAttention, etc.
- **Use nightly builds**: Stay on bleeding edge unless critical bugs
- **Test thoroughly**: CPU launcher must pass validation

## Preinstall Hints

### System Requirements
- **OS**: Windows (windows-latest runner for CI)
- **Python**: 3.13 from python-build-standalone
- **CUDA**: 13.0 support required
- **Tools**: 7zip must be available at `C:\Program Files\7-Zip\7z.exe`

### PyTorch Index
```
--index-url https://download.pytorch.org/whl/cu130
```

### Performance Wheels Sources
1. **FlashAttention**: `https://github.com/mjun0812/flash-attention-prebuild-wheels`
2. **SageAttention**: `https://github.com/woct0rdho/SageAttention`
3. **triton-windows**: `https://github.com/woct0rdho/triton-windows`
4. **Nunchaku**: `https://github.com/nunchaku-tech/nunchaku`
5. **NATTEN**: Curated AI-windows-whl sources

### Environment Setup
```bash
export PYTHONPYCACHEPREFIX="${workdir}/pycache1"
export PIP_NO_WARN_SCRIPT_LOCATION=0
export HF_HUB_CACHE="$workdir/ComfyUI_Windows_portable/HuggingFaceHub"
export TORCH_HOME="$workdir/ComfyUI_Windows_portable/TorchHome"
```

### Git Configuration
```bash
git config --global core.autocrlf true
```

### Shallow Clone Pattern
```bash
gcs='git clone --depth=1 --no-tags --recurse-submodules --shallow-submodules'
```

## Testing Checklist

### Stage 1 Validation
- [ ] Python 3.13 installed successfully
- [ ] PyTorch nightly cu130 installed
- [ ] FlashAttention wheel installed
- [ ] SageAttention wheel installed  
- [ ] triton-windows installed (version <3.6)
- [ ] Nunchaku wheel installed
- [ ] All pak files processed without errors
- [ ] `pip list` shows correct versions

### Stage 2 Validation
- [ ] ComfyUI cloned from master
- [ ] All 40+ custom nodes cloned
- [ ] Attachments copied correctly
- [ ] Quick test passes: `--quick-test-for-ci --cpu`
- [ ] No Traceback errors in output
- [ ] Models downloaded by custom nodes
- [ ] Cleanup completed successfully

### Stage 3 Validation
- [ ] Package named `ComfyUI_Windows_portable_cu130.7z.*`
- [ ] Models separated to `models.zip.*`
- [ ] Split archives created at 2140000000 bytes
- [ ] All expected files present in package

### Launcher Testing
- [ ] run_maximum_fidelity.bat exists
- [ ] run_optimized_fidelity.bat exists
- [ ] Both launchers use correct PATH configuration
- [ ] Both launchers navigate with `cd /d %~dp0\..`
- [ ] CPU launcher validation passes
- [ ] No Traceback on test run

### Final Checks
- [ ] No secrets in repository
- [ ] Port 8188 preserved
- [ ] extra_model_paths.yaml.example unchanged
- [ ] Package naming follows cu130 convention
- [ ] Draft release created with artifacts
- [ ] All logs reviewed for errors

## Common Issues and Solutions

### Traceback in Quick Test
**Problem**: Quick test shows Python Traceback  
**Solution**: Check missing dependencies, verify all custom nodes initialized

### Performance Wheels Not Found
**Problem**: FlashAttention or SageAttention not installed  
**Solution**: Verify wheel URLs, check Python version (must be cp313), verify CUDA version match

### Package Naming Wrong
**Problem**: Package named without cu130 suffix  
**Solution**: Update stage3.sh to use correct naming pattern

### Launcher PATH Issues
**Problem**: MinGit or Python not found by launcher  
**Solution**: Verify PATH includes `%~dp0\MinGit\cmd` and `%~dp0\python_standalone\Scripts`

### Build Timeout
**Problem**: Stage takes too long, CI times out  
**Solution**: Use shallow clones, check network issues, optimize package downloads

### Test Failures with taskkill
**Problem**: Log-guard tests fail on Windows  
**Solution**: Use `taskkill` command to terminate processes properly

## Notes for Contributors

### Before Making Changes
1. Read all instruction files in `.github/`
2. Understand the three-stage build process
3. Review existing launchers and their patterns
4. Check compatibility requirements

### When Adding Dependencies
1. Prefer nightly/bleeding-edge versions
2. Verify compatibility with Python 3.13 and CUDA 13.0
3. Test with quick test before committing
4. Document in appropriate pak*.txt file

### When Modifying Launchers
1. Preserve PATH configuration pattern
2. Keep comments explaining fidelity modes
3. Test with CPU flag first
4. Validate no Traceback errors

### When Updating Documentation
1. Keep port 8188 documentation unchanged
2. Maintain compatibility notes
3. Update version numbers if changed
4. Preserve security guidelines
