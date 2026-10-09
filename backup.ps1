# Обновляет config-backup/ копиями живых файлов из ~/.claude
$src = Join-Path $env:USERPROFILE ".claude"
$dst = Join-Path $PSScriptRoot "config-backup"

New-Item -ItemType Directory -Force (Join-Path $dst "agents") | Out-Null
Copy-Item (Join-Path $src "settings.json") $dst -Force
Copy-Item (Join-Path $src "CLAUDE.md") $dst -Force
Copy-Item (Join-Path $src "agents\*.md") (Join-Path $dst "agents") -Force
if (Test-Path (Join-Path $src "skill-library")) {
    New-Item -ItemType Directory -Force (Join-Path $dst "skill-library") | Out-Null
    Copy-Item (Join-Path $src "skill-library\*") (Join-Path $dst "skill-library") -Recurse -Force
}
Write-Output "Backup updated: $dst"

# Обновить plugins.json из `claude plugin list --json`
if (Get-Command node -ErrorAction SilentlyContinue) {
    node (Join-Path $PSScriptRoot "lib\export-plugins.js") (Join-Path $PSScriptRoot "plugins.json")
} else {
    Write-Output "node не найден, plugins.json не обновлён"
}
