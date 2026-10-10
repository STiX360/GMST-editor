$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$projectRoot = Split-Path -Parent $PSScriptRoot
$destination = Join-Path $projectRoot 'test-dist\GMST-Editor-OpenMW-Test-Kit.zip'
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $destination) | Out-Null
$files = @('Test-GMST-Editor.cmd')
foreach ($relative in @('GMSTProfilesTest.omwscripts', 'GMSTProfilesSmoke.omwscripts',
    'GMSTProfiles.omwscripts', 'README.md', 'TESTING.md',
    'scripts\gmst_profiles\load.lua', 'scripts\gmst_profiles\player.lua',
    'scripts\gmst_profiles\menu.lua', 'l10n\GmstProfiles\en.yaml',
    'scripts\gmst_profiles\labels.lua',
    'scripts\gmst_profiles\editor_model.lua', 'scripts\gmst_profiles\test_player.lua',
    'scripts\gmst_profiles\test_smoke.lua', 'scripts\gmst_profiles\test_fixtures.lua',
    'tools\start-test.ps1', 'tests\test_editor.py', 'requirements-dev.txt')) {
    $files += $relative
}
$stream = [IO.File]::Open($destination, [IO.FileMode]::Create)
$zip = [IO.Compression.ZipArchive]::new($stream, [IO.Compression.ZipArchiveMode]::Create)
try {
    foreach ($file in $files) {
        [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip,
            (Join-Path $projectRoot $file), $file.Replace('\','/')) | Out-Null
    }
} finally {
    $zip.Dispose()
    $stream.Dispose()
}
Write-Host "Built $destination"
