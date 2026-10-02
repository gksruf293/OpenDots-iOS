# Requires PowerShell 7, Node.js 24, and Codex CLI installed with npm.
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$server = Join-Path $repo 'server'
$envFile = Join-Path $server '.env'
if (Test-Path -LiteralPath $envFile) { throw 'server/.env already exists. Keep your settings; edit it manually instead.' }
if (-not (Get-Command node -ErrorAction SilentlyContinue)) { throw 'Install Node.js 24 first.' }
$major = [int]((& node --version).TrimStart('v').Split('.')[0])
if ($major -ne 24) { throw 'Use Node.js 24 LTS for this experimental release.' }
$npmRoot = (& npm root -g).Trim()
if ($LASTEXITCODE -ne 0) { throw 'Cannot locate global npm packages.' }
$codexRoot = Join-Path $npmRoot '@openai\codex'
$executables = @(Get-ChildItem -LiteralPath $codexRoot -Filter codex.exe -Recurse -File -ErrorAction SilentlyContinue)
$codex = $executables | Where-Object { $_.FullName -match 'x86_64-pc-windows-msvc' } | Select-Object -First 1
if (-not $codex) { throw 'Install Codex CLI: npm install -g @openai/codex@0.157.1 (Windows x64 tested).' }
& $codex.FullName login status
if ($LASTEXITCODE -ne 0) { throw 'Run codex login with your ChatGPT account first.' }
Push-Location $server
try {
    & npm ci
    if ($LASTEXITCODE -ne 0) { throw 'npm ci failed.' }
    & npm run build
    if ($LASTEXITCODE -ne 0) { throw 'Server build failed.' }
} finally { Pop-Location }
$token = [Convert]::ToHexString([Security.Cryptography.RandomNumberGenerator]::GetBytes(24)).ToLowerInvariant()
$lines = @('HOST=127.0.0.1','PORT=4310','AGENT_BACKEND=codex',('CODEX_COMMAND='+$codex.FullName),('OWNER_TOKEN='+$token))
[IO.File]::WriteAllLines($envFile,$lines,[Text.UTF8Encoding]::new($false))
$private = Join-Path $repo '.local-tools'
New-Item -ItemType Directory -Path $private -Force | Out-Null
[IO.File]::WriteAllLines((Join-Path $private 'connection.txt'),@('Server URL: set your HTTPS endpoint here',('Server token: '+$token)),[Text.UTF8Encoding]::new($false))
Write-Host 'Ready. Run ./scripts/start-server.ps1. Your private token is in .local-tools/connection.txt.'
