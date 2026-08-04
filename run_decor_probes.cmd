@echo off
if exist shots\decor_audit\probes rmdir /s /q shots\decor_audit\probes
set "DECOR_CONFIG=res://decor_camera_probes.json"
"C:\Users\litvi\OneDrive\Desktop\godot\Godot_v4.7-stable_win64_console.exe" --path . --script res://game/test_decor_capture.gd
exit /b %errorlevel%
