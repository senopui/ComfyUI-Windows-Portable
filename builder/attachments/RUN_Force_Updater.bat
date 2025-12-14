setlocal
set PATH=%PATH%;%~dp0MinGit\cmd;%~dp0python_standalone\Scripts
set PYTHONPYCACHEPREFIX=%~dp0pycache
.\python_standalone\python.exe -s -B force_updater.py
endlocal
