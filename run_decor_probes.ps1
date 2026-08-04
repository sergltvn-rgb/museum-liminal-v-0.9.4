$ErrorActionPreference = 'Stop'
$root = (Get-Location).Path
$probeDir = Join-Path $root 'shots\decor_audit\probes'
if (Test-Path $probeDir) { Remove-Item -Recurse -Force $probeDir }
$outLog = Join-Path $root 'shots\decor_audit\probe.stdout.log'
$errLog = Join-Path $root 'shots\decor_audit\probe.stderr.log'
$pidFile = Join-Path $root 'shots\decor_audit\probe.pid'
Remove-Item $outLog,$errLog,$pidFile -ErrorAction SilentlyContinue
$env:DECOR_CONFIG = 'res://decor_camera_probes.json'
$godot = 'C:\Users\litvi\OneDrive\Desktop\godot\Godot_v4.7-stable_win64_console.exe'
$p = Start-Process -FilePath $godot -ArgumentList @('--path','.', '--script','res://game/test_decor_capture.gd') -WorkingDirectory $root -RedirectStandardOutput $outLog -RedirectStandardError $errLog -PassThru
$p.Id | Set-Content -Path $pidFile -Encoding ascii
Write-Output ("started pid={0}" -f $p.Id)
