# ExtraScripts Directory Instructions

This directory contains specialized launcher scripts for ComfyUI with different performance and fidelity profiles.

## Launcher Location

**IMPORTANT**: Launchers in ExtraScripts/ directory are meant to be copied to the parent ComfyUI_Windows_portable/ directory before use. The "!Please copy these files to the parent folder first before using them" file indicates this requirement.

Once copied to the parent directory, launchers use relative paths to access:
- `.\\python_standalone\\python.exe` - Python executable
- `ComfyUI\\main.py` - ComfyUI main script
- `MinGit\\cmd` - Git commands
- Other directories relative to the installation root

## PATH Configuration

All launchers must prepend portable Git to PATH using `%~dp0`:
```batch
set PATH=%PATH%;%~dp0MinGit\\cmd;%~dp0python_standalone\\Scripts
```

Where `%~dp0` refers to the directory containing the launcher (the installation root after copying). The %~dp0 variable already includes a trailing backslash, so subdirectories are referenced directly.

**Correct**: `%~dp0MinGit\\cmd` (no extra backslash between %~dp0 and MinGit)  
**Incorrect**: `%~dp0\\MinGit\\cmd` (extra backslash creates double backslash)

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
.\\python_standalone\\python.exe -s -B ComfyUI\\main.py --disable-xformers --disable-smart-memory %*
```

Note: Use `.\\` prefix to explicitly reference current directory executables.

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

@REM Set PATH to include portable Git and Python scripts
set PATH=%PATH%;%~dp0MinGit\\cmd;%~dp0python_standalone\\Scripts

@REM Set cache directories
set HF_HUB_CACHE=%~dp0HuggingFaceHub
set TORCH_HOME=%~dp0TorchHome
set PYTHONPYCACHEPREFIX=%~dp0pycache

.\\python_standalone\\python.exe -s -B ComfyUI\\main.py --disable-xformers --disable-smart-memory %*

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
.\\python_standalone\\python.exe -s -B ComfyUI\\main.py %*
```

Note: Use `.\\` prefix to explicitly reference current directory executables.

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

@REM Set PATH to include portable Git and Python scripts
set PATH=%PATH%;%~dp0MinGit\\cmd;%~dp0python_standalone\\Scripts

@REM Set cache directories
set HF_HUB_CACHE=%~dp0HuggingFaceHub
set TORCH_HOME=%~dp0TorchHome
set PYTHONPYCACHEPREFIX=%~dp0pycache

.\\python_standalone\\python.exe -s -B ComfyUI\\main.py %*

endlocal
pause
```

## Common Elements

### Environment Variables
All launchers should set these environment variables:
```batch
set HF_HUB_CACHE=%~dp0HuggingFaceHub
set TORCH_HOME=%~dp0TorchHome
set PYTHONPYCACHEPREFIX=%~dp0pycache
```

### Script Structure
```batch
@echo off
@REM Suppress command echo
setlocal
@REM Isolate environment changes
@REM [set PATH and environment variables here]
@REM Configure paths and cache directories
@REM [execute ComfyUI command with relative paths here]
endlocal
@REM Restore environment
pause
@REM Wait for user before closing
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
python_standalone\\python.exe -s -B ComfyUI\\main.py --quick-test-for-ci --cpu
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
- Verify MinGit was extracted properly in the installation root
- Check PATH setting uses `%~dp0MinGit\\cmd`
- Verify launcher was copied to installation root directory

### Python Not Found
If python.exe not found:
- Check python_standalone directory exists in installation root
- Verify relative path `.\\python_standalone\\python.exe` is accessible
- Confirm launcher is in the installation root directory, not in ExtraScripts/

### Performance Issues
If optimized mode is slow:
- Check that xformers is installed
- Verify FlashAttention wheel is present
- Review pip list for performance packages
