@echo off
setlocal EnableExtensions
cd /d "%~dp0"

rem ============================================================================
rem verify.cmd -- ONE command, ONE short verdict.
rem
rem WHY THIS EXISTS
rem An agent that runs six separate checks by hand and reads six full logs
rem spends its whole context budget on verification and then has nothing left
rem to write down what it did. That is the failure this file removes.
rem The full output always goes to .tmp\verify.log; the console gets <= 20
rem lines. Read the verdict, not the log.
rem
rem USAGE
rem   verify.cmd             same as: verify.cmd geometry
rem   verify.cmd geometry    import + test_map_verification + node counters
rem   verify.cmd materials   check_materials + check_doors + check_museum_entrance
rem   verify.cmd full        run_tests.cmd, all seven suites
rem
rem IMPORTANT
rem Godot exits non-zero on "N resources still in use at exit" even on a clean
rem run, so this script does NOT gate on the exit code. Judge by the VERDICT
rem block. Capture tests are not run here: they need a window, not --headless.
rem ============================================================================

set "SCOPE=%~1"
if "%SCOPE%"=="" set "SCOPE=geometry"

if not exist ".tmp" mkdir ".tmp"
set "LOG=.tmp\verify.log"
del /q "%LOG%" 2>nul

call :locate_godot
if errorlevel 1 exit /b 1
echo [INFO] scope=%SCOPE%
echo [INFO] godot=%GODOT%
echo [INFO] log=%LOG%

if /i "%SCOPE%"=="geometry"  goto :geometry
if /i "%SCOPE%"=="materials" goto :materials
if /i "%SCOPE%"=="full"      goto :full
echo [ERROR] unknown scope "%SCOPE%" -- use geometry, materials or full.
exit /b 2

:geometry
call :step "import" --headless --editor --path "%CD%" --quit
call :script test_map_verification.gd
goto :verdict

:materials
call :tool check_materials.gd
call :tool check_doors.gd
call :tool check_museum_entrance.gd
goto :verdict

:full
echo [STEP] run_tests.cmd >>"%LOG%"
call run_tests.cmd >>"%LOG%" 2>&1
goto :verdict

rem --- verdict ----------------------------------------------------------------
rem One grep, fixed vocabulary. Every line below is a number or a ruling; no
rem line here is noise. If you need more, open the log yourself.
rem The terrabrush .dll error is known and permanent (the addon does not load in
rem this project, see .gitignore); "Failed to open" used to match /c:"FAIL" and
rem faked an [ATTENTION] on a fully green run, so it is filtered out here.
:verdict
echo.
echo ===================== VERDICT =====================
findstr /i /c:"MeshInstance3D" /c:"StaticBody3D" /c:"CollisionShape3D" /c:"Security cameras" /c:"ALL CHECKS" /c:"RESULT:" /c:"[DOORS]" /c:"[MUSEUM ENTRANCE]" /c:"[OK]" /c:"FAIL" /c:"SCRIPT ERROR" /c:"Parse Error" "%LOG%" | findstr /v /i /c:"terrabrush"
echo ===================================================
findstr /i /c:"FAIL" /c:"SCRIPT ERROR" /c:"Parse Error" "%LOG%" | findstr /v /i /c:"terrabrush" >nul 2>nul
if not errorlevel 1 (
  echo [ATTENTION] the log contains FAIL or a script error -- do not report "done".
) else (
  echo [CLEAN] no FAIL and no script error in the log.
)
echo.
echo Counters must be EXPLAINED, not just quoted: say why the delta is what it
echo is. A sharp rise in MeshInstance3D means a .glb did not resolve and the
echo primitive fallback was drawn instead.
echo Full log: %LOG%
exit /b 0

rem --- helpers ----------------------------------------------------------------
:step
echo. >>"%LOG%"
echo [STEP] %~1 >>"%LOG%"
shift
"%GODOT%" %1 %2 %3 %4 %5 %6 %7 %8 %9 >>"%LOG%" 2>&1
exit /b 0

:script
echo. >>"%LOG%"
echo [STEP] %~1 >>"%LOG%"
"%GODOT%" --headless --path "%CD%" --script "res://game/%~1" >>"%LOG%" 2>&1
exit /b 0

:tool
echo. >>"%LOG%"
echo [STEP] %~1 >>"%LOG%"
"%GODOT%" --headless --path "%CD%" --script "res://game/tools/%~1" >>"%LOG%" 2>&1
exit /b 0

:locate_godot
rem Same probe order as run_tests.cmd: GODOT -> PATH -> known install paths.
if defined GODOT (
  if exist "%GODOT%" exit /b 0
  where "%GODOT%" >nul 2>nul && exit /b 0
  echo [WARN] GODOT is set to "%GODOT%" but was not found; probing PATH.
  set "GODOT="
)
for %%G in (godot4.exe godot.exe Godot_v4.7-stable_win64_console.exe Godot_v4.7-stable_win64.exe) do (
  where %%G >nul 2>nul && set "GODOT=%%G" && exit /b 0
)
for %%P in (
  "%USERPROFILE%\OneDrive\Desktop\godot\Godot_v4.7-stable_win64_console.exe"
  "%USERPROFILE%\Desktop\godot\Godot_v4.7-stable_win64_console.exe"
  "%LOCALAPPDATA%\Programs\Godot\Godot_v4.7-stable_win64_console.exe"
  "%ProgramFiles%\Godot\Godot_v4.7-stable_win64_console.exe"
  "C:\Godot\Godot_v4.7-stable_win64_console.exe"
) do (
  if exist "%%~P" set "GODOT=%%~P" && exit /b 0
)
echo [ERROR] Godot 4.7 console executable was not found.
echo         Point GODOT at it, for example:
echo           set "GODOT=%%USERPROFILE%%\OneDrive\Desktop\godot\Godot_v4.7-stable_win64_console.exe"
exit /b 1
