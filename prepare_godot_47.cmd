@echo off
setlocal
cd /d "%~dp0"
echo Cleaning stale Godot class cache and pre-0.3 project files...
if exist "scripts" rmdir /s /q "scripts"
if exist ".godot" rmdir /s /q ".godot"
if exist "%APPDATA%\Godot\app_userdata\Museum Liminal" echo User settings preserved.
if exist "game\project.godot" del /f /q "game\project.godot"
if exist "scenes\project.godot" del /f /q "scenes\project.godot"
if exist "models\project.godot" del /f /q "models\project.godot"
if exist "audio\project.godot" del /f /q "audio\project.godot"
echo Done. Open project.godot in Godot 4.7 and wait for reimport.
endlocal
pause
