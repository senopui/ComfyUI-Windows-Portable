setlocal
set PATH=%PATH%;%~dp0\MinGit\cmd;%~dp0\python_standalone\Scripts
set PYTHONPYCACHEPREFIX=%~dp0\pycache
.\python_standalone\python.exe -s -B ComfyUI\main.py --cpu --windows-standalone-build
endlocal
pause
