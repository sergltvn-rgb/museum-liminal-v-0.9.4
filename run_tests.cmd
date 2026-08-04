@echo off
setlocal EnableExtensions
cd /d "%~dp0"

rem --- Locate Godot 4.7 -------------------------------------------------
rem Order: GODOT env var -> PATH -> common install locations. The old script
rem cleared GODOT and probed PATH only, so a developer with Godot installed
rem but not on PATH got "not found" and the suite never ran at all.
if defined GODOT (
  if exist "%GODOT%" goto :found
  where "%GODOT%" >nul 2>nul && goto :found
  echo [WARN] GODOT is set to "%GODOT%" but was not found; probing PATH.
  set "GODOT="
)
for %%G in (godot4.exe godot.exe Godot_v4.7-stable_win64_console.exe Godot_v4.7-stable_win64.exe) do (
  where %%G >nul 2>nul && set "GODOT=%%G" && goto :found
)
for %%P in (
  "%USERPROFILE%\OneDrive\Desktop\godot\Godot_v4.7-stable_win64_console.exe"
  "%USERPROFILE%\Desktop\godot\Godot_v4.7-stable_win64_console.exe"
  "%LOCALAPPDATA%\Programs\Godot\Godot_v4.7-stable_win64_console.exe"
  "%ProgramFiles%\Godot\Godot_v4.7-stable_win64_console.exe"
  "C:\Godot\Godot_v4.7-stable_win64_console.exe"
) do (
  if exist "%%~P" set "GODOT=%%~P" && goto :found
)
echo [ERROR] Godot 4.7 console executable was not found.
echo         Point GODOT at it, for example:
echo           set "GODOT=%%USERPROFILE%%\OneDrive\Desktop\godot\Godot_v4.7-stable_win64_console.exe"
exit /b 1

:found
echo [INFO] Using Godot: %GODOT%

rem CI imports the project before testing. Without this the .fbx/.glb models
rem do not resolve and the generated map is not the one CI verifies. Neither
rem stream is discarded and the exit code is checked now: a swallowed import
rem failure let all four suites run against a half-imported filesystem, so CI
rem reported whatever broke downstream and threw the real cause away.
rem Written flat with a goto rather than as an "if not defined (...)" block:
rem %errorlevel% inside a parenthesised block is expanded when the block is
rem parsed, before Godot has run, so it would always read 0.
if defined SKIP_IMPORT goto :imported
echo.
echo [STEP] Import project
"%GODOT%" --headless --editor --path "%CD%" --quit
set "code=%errorlevel%"
if not "%code%"=="0" (
  echo [FAIL] project import exited with %code%
  exit /b %code%
)
echo [PASS] project import
:imported

rem Same set and same order as .github/workflows/windows-release.yml.
call :run test_project_integration.gd
if errorlevel 1 exit /b %errorlevel%
call :run test_map_verification.gd
if errorlevel 1 exit /b %errorlevel%
call :run test_decor_quality.gd
if errorlevel 1 exit /b %errorlevel%
call :run test_decor_layout.gd
if errorlevel 1 exit /b %errorlevel%
call :run test_incident_catalog.gd
if errorlevel 1 exit /b %errorlevel%
call :run test_full_game_cycle.gd
if errorlevel 1 exit /b %errorlevel%
call :run test_blocker_regressions.gd
if errorlevel 1 exit /b %errorlevel%
echo.
echo [OK] All tests passed.
exit /b 0

:run
echo.
echo [STEP] %~1
"%GODOT%" --headless --path "%CD%" --script "res://game/%~1"
set "code=%errorlevel%"
if not "%code%"=="0" (
  echo [FAIL] %~1 exited with %code%
  exit /b %code%
)
echo [PASS] %~1
exit /b 0
