$ErrorActionPreference = 'Stop'
$root = (Get-Location).Path
$outDir = Join-Path $root 'shots\decor_audit\after'
if (Test-Path $outDir) { Remove-Item -Recurse -Force $outDir }
$outLog = Join-Path $root 'shots\decor_audit\final.stdout.log'
$errLog = Join-Path $root 'shots\decor_audit\final.stderr.log'
$pidFile = Join-Path $root 'shots\decor_audit\final.pid'
Remove-Item $outLog,$errLog,$pidFile -ErrorAction SilentlyContinue
$env:DECOR_CONFIG = 'res://decor_shots.json'
$godot = 'C:\Users\litvi\OneDrive\Desktop\godot\Godot_v4.7-stable_win64_console.exe'
$p = Start-Process -FilePath $godot -ArgumentList @('--path','.', '--script','res://game/test_decor_capture.gd') -WorkingDirectory $root -RedirectStandardOutput $outLog -RedirectStandardError $errLog -PassThru
$p.Id | Set-Content -Path $pidFile -Encoding ascii
Write-Output ("started pid={0}" -f $p.Id)
