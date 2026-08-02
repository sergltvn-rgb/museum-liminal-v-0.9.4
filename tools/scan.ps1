$root = Split-Path -Parent $PSScriptRoot
$files = @('GravityProps','SpaceProps')
foreach ($f in $files) {
  $path = Join-Path $root ('game\props\' + $f + '.gd')
  Write-Output ''
  Write-Output ('===== ' + $f + ' =====')
  Select-String -Path $path -Pattern 'StandardMaterial3D.new|static func .*[Mm]aterial|_mats|_materials' | ForEach-Object { Write-Output ('{0,5}: {1}' -f $_.LineNumber, $_.Line.Trim()) }
}
