setlocal
set PYTHONPYCACHEPREFIX=%~dp0pycache
.\python_standalone\python.exe -s -B launcher_cn.py
endlocal
