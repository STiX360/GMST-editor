$ErrorActionPreference = 'Stop'
python (Join-Path $PSScriptRoot 'release.py') package
if ($LASTEXITCODE -ne 0) { throw 'Production packaging failed' }
