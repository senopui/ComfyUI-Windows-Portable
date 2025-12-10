setlocal
set PATH=%PATH%;%~dp0MinGit\cmd;%~dp0python_standalone\Scripts
set PYTHONPYCACHEPREFIX=%~dp0pycache
.\python_standalone\python.exe -s ComfyUI\main.py --cpu --windows-standalone-build
endlocal
pause
