# Установка настройки Claude Code на Windows. Повторный запуск = обновление.
# -DryRun: только показать действия.
param([switch]$DryRun)

try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}
$ErrorActionPreference = 'Continue'

$Repo = $PSScriptRoot
$ClaudeDir = Join-Path $env:USERPROFILE '.claude'
$Cfg = Join-Path $Repo 'config-backup'
$Fails = New-Object System.Collections.ArrayList

function Step($t) { Write-Host ""; Write-Host "== $t ==" }

Step 'Проверка программ'
if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
    Write-Host 'Claude Code не найден в PATH. Установи его: https://code.claude.com/docs'
    Write-Host 'После установки запусти этот скрипт снова.'
    exit 1
}
Write-Host 'claude: найден'
$HaveNode = [bool](Get-Command node -ErrorAction SilentlyContinue)
if (-not $HaveNode) { Write-Host 'ВНИМАНИЕ: node не найден. Слияние настроек и список плагинов недоступны.' }

Step 'Резервная копия текущих файлов'
$Stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$Bk = Join-Path $ClaudeDir "backup-$Stamp"
foreach ($f in 'settings.json', 'CLAUDE.md') {
    $p = Join-Path $ClaudeDir $f
    if (Test-Path $p) {
        if ($DryRun) { Write-Host "[dry-run] копия $p -> $Bk" }
        else {
            New-Item -ItemType Directory -Force $Bk | Out-Null
            Copy-Item $p (Join-Path $Bk $f) -Force
            Write-Host "Копия $f -> $Bk"
        }
    }
}

Step 'Копирование файлов'
if ($DryRun) {
    Write-Host "[dry-run] создать $ClaudeDir\agents и $ClaudeDir\skill-library"
    Write-Host "[dry-run] копировать CLAUDE.md -> $ClaudeDir"
    Get-ChildItem (Join-Path $Cfg 'agents') -Filter *.md | ForEach-Object { Write-Host "[dry-run] копировать agents\$($_.Name)" }
    if (Test-Path (Join-Path $Cfg 'skill-library')) { Write-Host "[dry-run] копировать skill-library\* -> $ClaudeDir\skill-library" }
} else {
    New-Item -ItemType Directory -Force (Join-Path $ClaudeDir 'agents') | Out-Null
    New-Item -ItemType Directory -Force (Join-Path $ClaudeDir 'skill-library') | Out-Null
    Copy-Item (Join-Path $Cfg 'CLAUDE.md') (Join-Path $ClaudeDir 'CLAUDE.md') -Force
    Copy-Item (Join-Path $Cfg 'agents\*.md') (Join-Path $ClaudeDir 'agents') -Force
    if (Test-Path (Join-Path $Cfg 'skill-library')) {
        Copy-Item (Join-Path $Cfg 'skill-library\*') (Join-Path $ClaudeDir 'skill-library') -Recurse -Force
    }
}

Step 'Настройки (settings.json)'
$LiveSettings = Join-Path $ClaudeDir 'settings.json'
if ($HaveNode) {
    if ($DryRun) { Write-Host "[dry-run] node lib\merge-settings.js config-backup\settings.json $LiveSettings" }
    else { node (Join-Path $Repo 'lib\merge-settings.js') (Join-Path $Cfg 'settings.json') $LiveSettings }
} elseif (-not (Test-Path $LiveSettings)) {
    if ($DryRun) { Write-Host "[dry-run] копировать settings.json -> $LiveSettings" }
    else { Copy-Item (Join-Path $Cfg 'settings.json') $LiveSettings -Force }
} else {
    Write-Host "node нет, а settings.json уже существует. Объедини вручную с $Cfg\settings.json"
}

# Запускает claude, не прерывая скрипт при ошибке
function Try-Claude($label, [string[]]$cmdArgs) {
    if ($DryRun) { Write-Host ("[dry-run] claude " + ($cmdArgs -join ' ')); return }
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $out = & claude @cmdArgs 2>&1 | Out-String
    $code = $LASTEXITCODE
    $ErrorActionPreference = $prev
    if ($code -ne 0) {
        if ($out -match 'already') { Write-Host "  уже есть: $label" }
        else { Write-Host "  ОШИБКА: $label"; [void]$Fails.Add("${label}: $($out.Trim())") }
    } else { Write-Host "  ok: $label" }
}

Step 'Плагины'
$PluginsFile = Join-Path $Repo 'plugins.json'
if (Test-Path $PluginsFile) {
    $pl = Get-Content $PluginsFile -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($m in @($pl.marketplaces)) { if ($m) { Try-Claude "marketplace $m" @('plugin', 'marketplace', 'add', $m) } }
    foreach ($p in @($pl.enabled)) {
        if ($p) {
            Try-Claude "install $p" @('plugin', 'install', $p)
            Try-Claude "enable $p" @('plugin', 'enable', $p, '--scope', 'user')
        }
    }
    foreach ($p in @($pl.disabled)) {
        if ($p) {
            Try-Claude "install $p" @('plugin', 'install', $p)
            Try-Claude "disable $p" @('plugin', 'disable', $p, '--scope', 'user')
        }
    }
    foreach ($p in @($pl.disabledSynced)) {
        if ($p) { Try-Claude "disable $p" @('plugin', 'disable', $p, '--scope', 'user') }
    }
} else {
    Write-Host 'plugins.json не найден, пропускаю плагины.'
}

Step 'Настройки VS Code'
$Vsc = Join-Path $env:APPDATA 'Code\User\settings.json'
if (Test-Path $Vsc) {
    if (-not $HaveNode) { Write-Host 'node нет, пропускаю VS Code.' }
    elseif ($DryRun) { Write-Host "[dry-run] node lib\merge-vscode.js $Vsc" }
    else { node (Join-Path $Repo 'lib\merge-vscode.js') $Vsc }
} else {
    Write-Host "Настройки VS Code не найдены ($Vsc). Если пользуешься расширением, добавь: `"claudeCode.initialPermissionMode`": `"plan`""
}

Step 'Итог'
if ($DryRun) { Write-Host '[dry-run] claude plugin list' } else { claude plugin list }
if ($Fails.Count -gt 0) {
    Write-Host ''
    Write-Host 'Не удалось выполнить:'
    foreach ($f in $Fails) { Write-Host " - $f" }
}
Write-Host ''
Write-Host 'Сделай вручную:'
Write-Host ' 1. Открой новый чат в Claude Code.'
Write-Host ' 2. Выполни /mcp и авторизуй context7.'
Write-Host ' 3. Проверь, что чат открылся в режиме Plan и с моделью Opus.'
