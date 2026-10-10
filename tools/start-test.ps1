param(
    [string]$Engine = 'C:\Modlists\POTI\.OpenMW\openmw.exe',
    [string]$GameData = 'D:\Steam\steamapps\common\Morrowind\Data Files',
    [switch]$PrepareOnly,
    [switch]$SmokeTest
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$enginePath = (Resolve-Path -LiteralPath $Engine).Path
$gamePath = (Resolve-Path -LiteralPath $GameData).Path
$resources = Join-Path (Split-Path -Parent $enginePath) 'resources'
$version = (Get-Content -LiteralPath (Join-Path $resources 'version') -TotalCount 1).Trim()
if ($version -notmatch '^0\.52\.') { throw "This test targets OpenMW 0.52; found $version" }
if (-not $PrepareOnly -and (Get-Process -Name openmw -ErrorAction SilentlyContinue)) {
    throw 'Close OpenMW before starting this test.'
}
foreach ($file in @('Morrowind.esm', 'Morrowind.bsa')) {
    if (-not (Test-Path -LiteralPath (Join-Path $gamePath $file))) { throw "Missing $file" }
}
$name = if ($SmokeTest) { 'smoke' } else { 'manual' }
$profile = Join-Path $projectRoot ".runtime\$name-profile"
$userData = Join-Path $projectRoot ".runtime\$name-user-data"
$localData = Join-Path $userData 'data'
New-Item -ItemType Directory -Force -Path $profile,$userData,$localData | Out-Null
$lines = @(
    'replace=config', 'replace=data', 'replace=content', 'replace=groundcover',
    'replace=fallback-archive',
    ('resources="' + $resources.Replace('\','/') + '"'),
    ('data="' + $resources.Replace('\','/') + '/vfs-mw"'),
    ('data="' + $gamePath.Replace('\','/') + '"'),
    ('data="' + $projectRoot.Replace('\','/') + '"'),
    ('data-local="' + $localData.Replace('\','/') + '"'),
    'content=Morrowind.esm', 'fallback-archive=Morrowind.bsa',
    'content=GMSTProfilesTest.omwscripts'
)
foreach ($archive in @('Tribunal.bsa', 'Bloodmoon.bsa')) {
    if (Test-Path -LiteralPath (Join-Path $gamePath $archive)) { $lines += 'fallback-archive=' + $archive }
}
if ($SmokeTest) { $lines += 'content=GMSTProfilesSmoke.omwscripts' }
[IO.File]::WriteAllLines((Join-Path $profile 'openmw.cfg'), $lines)
$settings = Join-Path $profile 'settings.cfg'
if (-not (Test-Path -LiteralPath $settings)) {
    [IO.File]::WriteAllText($settings, "[Video]`nresolution x = 1920`nresolution y = 1080`nfullscreen = false`n[Sound]`nmusic volume = 0`n")
}
Write-Host "OpenMW $version; log: $profile\openmw.log"
Write-Host "Isolated saves/storage: $userData"
if ($PrepareOnly) { return }
$arguments = @('--replace', 'config', '--config', ('"' + $profile + '"'),
    '--user-data', ('"' + $userData + '"'), '--skip-menu', '--new-game=0', '--start', '"Seyda Neen"', '--no-grab')
$windowStyle = if ($SmokeTest) { 'Hidden' } else { 'Normal' }
$runs = if ($SmokeTest) { 4 } else { 1 }
for ($run = 0; $run -lt $runs; $run++) {
    $diagnostics = @{}
    if ($SmokeTest) {
        $diagnostics.RedirectStandardOutput = Join-Path $profile "stage-$run.stdout.log"
        $diagnostics.RedirectStandardError = Join-Path $profile "stage-$run.stderr.log"
    }
    $process = Start-Process -FilePath $enginePath -WorkingDirectory (Split-Path -Parent $enginePath) `
        -WindowStyle $windowStyle -ArgumentList $arguments -PassThru @diagnostics
    if (-not $SmokeTest) { break }
    # Retain the process handle so ExitCode remains available after an early exit.
    $handle = $process.Handle
    if (-not $process.WaitForExit(45000)) {
        $process.Kill()
        $process.WaitForExit()
        throw "Smoke test timed out. See $profile\openmw.log"
    }
    $log = Get-Content -LiteralPath (Join-Path $profile 'openmw.log') -Raw
    if ($process.ExitCode -ne 0 -or $log -notmatch "GMST_EDITOR_SMOKE_PASS: stage=$run " -or $log -match 'GMST_EDITOR_SMOKE_FAIL| E\]|renderer .*error:') {
        throw "Smoke test failed (exit code $($process.ExitCode)). See $profile\openmw.log"
    }
    Copy-Item -LiteralPath (Join-Path $profile 'openmw.log') -Destination (Join-Path $profile "stage-$run.log")
    Write-Host "GMST_EDITOR_SMOKE_PASS: stage $run"
}
