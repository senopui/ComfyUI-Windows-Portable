setlocal
set PATH=%PATH%;%~dp0MinGit\cmd;%~dp0python_standalone\Scripts
set PYTHONPYCACHEPREFIX=%~dp0pycache
.\python_standalone\python.exe -s -B scripts\preflight_accel.py
.\python_standalone\python.exe -s -B ComfyUI\main.py --cpu --windows-standalone-build
endlocal
pause
