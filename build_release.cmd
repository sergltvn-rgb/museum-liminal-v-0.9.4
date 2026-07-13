@echo off
setlocal
cd /d "%~dp0"

set "GODOT="
for %%G in (godot4.exe godot.exe Godot_v4.7-stable_win64_console.exe) do (
  where %%G >nul 2>nul && set "GODOT=%%G" && goto :found
)

echo [ERROR] Godot 4.7 console executable was not found in PATH.
echo Add Godot to PATH or place Godot_v4.7-stable_win64_console.exe next to this script.
exit /b 1

:found
if not exist "build\windows" mkdir "build\windows"
if not exist "build\linux" mkdir "build\linux"
if not exist "build\web" mkdir "build\web"

echo [1/4] Importing and validating project...
%GODOT% --headless --path "%CD%" --editor --quit-after 3
if errorlevel 1 exit /b %errorlevel%

echo [2/4] Running map verification...
call run_tests.cmd
if errorlevel 1 exit /b %errorlevel%

echo [3/4] Exporting Windows release...
%GODOT% --headless --path "%CD%" --export-release "Windows Desktop" "build\windows\MuseumLiminal.exe"
if errorlevel 1 exit /b %errorlevel%

echo [4/4] Build complete: build\windows\MuseumLiminal.exe
exit /b 0
