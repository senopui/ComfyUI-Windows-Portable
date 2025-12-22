@echo off
setlocal

@REM Maximum Fidelity Mode - Favors quality and stability over speed
@REM - Disables xformers (uses PyTorch's native attention for maximum compatibility)
@REM - Disables smart memory management (more conservative memory handling)
@REM - Default port 8188 (compatible with character_select_stand_alone_app_test)

@REM If you don't want the browser to open automatically, add [ --disable-auto-launch ] after the last argument.
set "EXTRA_ARGS=--disable-auto-launch --disable-xformers --disable-smart-memory"

@REM To set proxy, edit and uncomment the two lines below (remove 'rem ' in the beginning of line).
rem set HTTP_PROXY=http://localhost:1080
rem set HTTPS_PROXY=http://localhost:1080

@REM To set mirror site for PIP & HuggingFace Hub, uncomment and edit the two lines below.
rem set PIP_INDEX_URL=https://mirrors.cernet.edu.cn/pypi/web/simple
rem set HF_ENDPOINT=https://hf-mirror.com

@REM To set HuggingFace Access Token, uncomment and edit the line below.
@REM https://huggingface.co/settings/tokens
rem set HF_TOKEN=

@REM ==========================================================================
@REM The following content generally does not require user modification.

@REM This command redirects HuggingFace-Hub to download model files in this folder.
set HF_HUB_CACHE=%~dp0HuggingFaceHub

@REM This command redirects Pytorch Hub to download model files in this folder.
set TORCH_HOME=%~dp0TorchHome

@REM This command will set PATH environment variable.
set PATH=%PATH%;%~dp0MinGit\cmd;%~dp0python_standalone\Scripts

@REM This command will let the .pyc files to be stored in one place.
set PYTHONPYCACHEPREFIX=%~dp0pycache

.\python_standalone\python.exe -s -B ComfyUI\main.py --windows-standalone-build %EXTRA_ARGS%

endlocal
pause
