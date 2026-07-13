@echo off
setlocal
cd /d "%~dp0"
set "GODOT="
for %%G in (godot4.exe godot.exe Godot_v4.7-stable_win64_console.exe) do (
  where %%G >nul 2>nul && set "GODOT=%%G" && goto :found
)
echo [ERROR] Godot 4.7 console executable was not found.
exit /b 1
:found
%GODOT% --headless --path "%CD%" --script res://game/test_map_verification.gd
if errorlevel 1 exit /b %errorlevel%
%GODOT% --headless --path "%CD%" --script res://game/test_project_integration.gd
if errorlevel 1 exit /b %errorlevel%
%GODOT% --headless --path "%CD%" --script res://game/test_incident_catalog.gd
exit /b %errorlevel%
