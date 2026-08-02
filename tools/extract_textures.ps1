# Unpacks PBR texture sets from models/*.zip into textures/<set>/.
# Only the map slots the engine actually samples are extracted; previews,
# displacement and 8K variants stay inside the archives so the working tree
# does not balloon.
#
# Run from the project root:
#   powershell -NoProfile -ExecutionPolicy Bypass -File tools\extract_textures.ps1

Add-Type -AssemblyName System.IO.Compression.FileSystem

$root = Split-Path -Parent $PSScriptRoot
$zipDir = Join-Path $root 'models'
$outRoot = Join-Path $root 'textures'

$sets = @(
	'Poliigon_MetalRust_7642',
	'Poliigon_PlasticMoldDryBlast_7495',
	'Poliigon_PlasticMoldWorn_7486',
	'GroundDirtRocky020',
	'CityStreetAsphaltGenericClean001'
)

$keep = 'COL|Color|NRM|Normal|ROUGH|GLOSS|_AO|AO_|AmbientOcclusion|METAL|Metal'
$drop = 'PREVIEW|Preview|Sphere|Flat|8K|CUBE|DISP|BUMP|IDMAP|ALPHAMASKED'

foreach ($name in $sets) {
	$zipPath = Join-Path $zipDir ($name + '.zip')
	if (-not (Test-Path $zipPath)) {
		Write-Output ('MISSING ' + $name)
		continue
	}

	$outDir = Join-Path $outRoot $name
	New-Item -ItemType Directory -Force -Path $outDir | Out-Null

	$zip = [System.IO.Compression.ZipFile]::OpenRead($zipPath)
	$taken = 0
	foreach ($entry in $zip.Entries) {
		if ($entry.Name -eq '') { continue }
		if ($entry.Name -notmatch '\.(jpg|png)$') { continue }
		if ($entry.Name -notmatch $keep) { continue }
		if ($entry.Name -match $drop) { continue }

		$dest = Join-Path $outDir $entry.Name
		[System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $dest, $true)
		$taken = $taken + 1
		Write-Output ('  {0,9:N0}  {1}' -f $entry.Length, $entry.Name)
	}
	$zip.Dispose()
	Write-Output ('[done] ' + $name + '  files=' + $taken)
}
