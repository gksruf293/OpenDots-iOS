$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$server = Join-Path $repo 'server'
if (-not (Test-Path -LiteralPath (Join-Path $server '.env'))) { throw 'Run setup-server.ps1 first.' }
Push-Location $server
try {
    & node --env-file=.env dist/server/server/index.js
    if ($LASTEXITCODE -ne 0) { throw 'OpenDots server exited with an error.' }
} finally { Pop-Location }
