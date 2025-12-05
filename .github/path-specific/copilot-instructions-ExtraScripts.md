# ExtraScripts Directory Instructions

This directory contains specialized launcher scripts for ComfyUI with different performance and fidelity profiles.

## Launcher Navigation Pattern

All launchers must use this directory navigation pattern:
```batch
cd /d %~dp0\..
```

This changes to the parent directory where the actual ComfyUI installation resides.

## PATH Configuration

All launchers must prepend portable Git to PATH:
```batch
set PATH=%PATH%;%~dp0\MinGit\cmd;%~dp0\python_standalone\Scripts
```

This ensures:
- MinGit commands are available for updates
- Python scripts in Scripts directory are accessible

## run_maximum_fidelity.bat

### Purpose
Maximum fidelity launcher prioritizes output quality and stability over performance. Best for:
- Production renders
- Final quality outputs
- Situations where accuracy matters most

### Command
```batch
python_standalone\python.exe -s -B ComfyUI\main.py --disable-xformers --disable-smart-memory %*
```

### Flags Explained
- `-s`: No site packages (isolated environment)
- `-B`: Don't write .pyc files
- `--disable-xformers`: Disables xformers optimizations for maximum accuracy
- `--disable-smart-memory`: Disables smart memory management for stability
- `%*`: Pass through all command line arguments

### Comments to Include
```batch
@REM Maximum fidelity mode
@REM Disables performance optimizations (xformers, smart memory) for best quality
@REM Use this when you need the most accurate and stable results
@REM Slower than optimized mode but produces the most consistent output
```

### Full Script Structure
```batch
@echo off
setlocal

@REM Maximum fidelity mode
@REM Disables performance optimizations (xformers, smart memory) for best quality
@REM Use this when you need the most accurate and stable results

cd /d %~dp0\..

@REM Set PATH to include portable Git and Python scripts
set PATH=%PATH%;%~dp0\MinGit\cmd;%~dp0\python_standalone\Scripts

@REM Set cache directories
set HF_HUB_CACHE=%~dp0\HuggingFaceHub
set TORCH_HOME=%~dp0\TorchHome
set PYTHONPYCACHEPREFIX=%~dp0\pycache

python_standalone\python.exe -s -B ComfyUI\main.py --disable-xformers --disable-smart-memory %*

endlocal
pause
```

## run_optimized_fidelity.bat

### Purpose
Optimized launcher uses default settings with all performance optimizations enabled. Best for:
- Interactive workflows
- Iterative development
- Fast previews and testing

### Command
```batch
python_standalone\python.exe -s -B ComfyUI\main.py %*
```

### Flags Explained
- `-s`: No site packages (isolated environment)
- `-B`: Don't write .pyc files
- `%*`: Pass through all command line arguments
- No disable flags = xformers and FlashAttention enabled by default

### Features Enabled
- **xformers**: Memory-efficient attention mechanisms
- **FlashAttention**: Fast attention implementation (from pak8.txt)
- **Smart memory management**: Dynamic memory allocation
- **Auto precision**: Automatic mixed precision for performance
- **SageAttention**: Optional advanced attention (if configured)

### Comments to Include
```batch
@REM Optimized fidelity mode (default)
@REM Uses performance optimizations: xformers, FlashAttention, smart memory
@REM Auto-precision mode enabled for faster processing
@REM Best for interactive work and fast iterations
```

### Full Script Structure
```batch
@echo off
setlocal

@REM Optimized fidelity mode (default)
@REM Uses performance optimizations: xformers, FlashAttention, smart memory
@REM Auto-precision mode enabled for faster processing
@REM Best for interactive work and fast iterations

cd /d %~dp0\..

@REM Set PATH to include portable Git and Python scripts
set PATH=%PATH%;%~dp0\MinGit\cmd;%~dp0\python_standalone\Scripts

@REM Set cache directories
set HF_HUB_CACHE=%~dp0\HuggingFaceHub
set TORCH_HOME=%~dp0\TorchHome
set PYTHONPYCACHEPREFIX=%~dp0\pycache

python_standalone\python.exe -s -B ComfyUI\main.py %*

endlocal
pause
```

## Common Elements

### Environment Variables
All launchers should set these environment variables:
```batch
set HF_HUB_CACHE=%~dp0\HuggingFaceHub
set TORCH_HOME=%~dp0\TorchHome
set PYTHONPYCACHEPREFIX=%~dp0\pycache
```

### Script Structure
```batch
@echo off                  # Suppress command echo
setlocal                   # Isolate environment changes
cd /d %~dp0\..            # Navigate to parent directory
[set environment vars]     # Configure paths and cache
[run command]             # Execute ComfyUI
endlocal                   # Restore environment
pause                      # Wait for user before closing
```

## Directory Structure

Expected directory layout relative to ExtraScripts:
```
ComfyUI_Windows_portable/
├── ExtraScripts/
│   ├── run_maximum_fidelity.bat
│   ├── run_optimized_fidelity.bat
│   └── [other scripts]
├── ComfyUI/
│   └── main.py
├── python_standalone/
│   └── python.exe
├── MinGit/
│   └── cmd/
├── HuggingFaceHub/
├── TorchHome/
└── pycache/
```

## Performance Notes

### Maximum Fidelity Mode
- **Speed**: Slower (no optimizations)
- **Memory**: Higher and more stable allocation
- **Quality**: Highest, most consistent
- **Use case**: Final renders, production work

### Optimized Fidelity Mode
- **Speed**: Faster (xformers, FlashAttention enabled)
- **Memory**: Lower, dynamically managed
- **Quality**: High, with minor variations possible
- **Use case**: Development, testing, interactive work

## Testing

When testing launchers:
1. Verify they can navigate to correct directories
2. Check that Python executable is found
3. Ensure MinGit PATH is properly set
4. Validate environment variables are set correctly
5. Test with `--quick-test-for-ci` flag first

### Test Command
```batch
python_standalone\python.exe -s -B ComfyUI\main.py --quick-test-for-ci --cpu
```

## Compatibility

### Port Configuration
- Default port: 8188
- Don't override unless user explicitly requests
- Launchers should not force port changes

### Argument Pass-Through
- Always use `%*` to pass additional arguments
- Users can add `--port 8189` or other flags
- Preserve user's command-line options

## Troubleshooting

### Path Issues
If MinGit not found:
- Verify MinGit was extracted properly
- Check PATH setting includes correct directory
- Use full path if necessary: `%~dp0..\MinGit\cmd`

### Python Not Found
If python.exe not found:
- Verify navigation with `cd /d %~dp0\..`
- Check python_standalone directory exists
- Use full path: `%~dp0..\python_standalone\python.exe`

### Performance Issues
If optimized mode is slow:
- Check that xformers is installed
- Verify FlashAttention wheel is present
- Review pip list for performance packages
