# start-dev.ps1 — поднимает всю связку «Клинок Памяти» одной командой.
#
#   powershell -ExecutionPolicy Bypass -File tools\start-dev.ps1
#
# Что делает:
#   1) открывает KlinokPamyati123.rbxl в Roblox Studio, если Studio не запущена;
#   2) открывает папку проекта в VS Code;
#   3) проверяет, что мост MCP видит Studio (tools\status.js).

param(
    [string]$Place = "C:\Users\artem\Desktop\KlinokPamyati123.rbxl",
    [string]$ProjectRoot = "C:\Users\artem\KlinokPamyati"
)

$ErrorActionPreference = "Continue"

function Find-StudioExe {
    $base = Join-Path $env:LOCALAPPDATA "Roblox\Versions"
    if (-not (Test-Path $base)) { return $null }
    $candidates = Get-ChildItem $base -Directory |
        ForEach-Object { Join-Path $_.FullName "RobloxStudioBeta.exe" } |
        Where-Object { Test-Path $_ } |
        Sort-Object { (Get-Item $_).LastWriteTime } -Descending
    return $candidates | Select-Object -First 1
}

Write-Host "[1/3] Roblox Studio" -ForegroundColor Cyan
$studioProcess = Get-Process RobloxStudioBeta -ErrorAction SilentlyContinue
if ($studioProcess) {
    Write-Host "  уже запущена (PID $($studioProcess[0].Id)) — окно: $($studioProcess[0].MainWindowTitle)"
} else {
    if (-not (Test-Path $Place)) {
        Write-Host "  плейс не найден: $Place" -ForegroundColor Red
    } else {
        $exe = Find-StudioExe
        if (-not $exe) {
            Write-Host "  не нашёл RobloxStudioBeta.exe в LOCALAPPDATA\Roblox\Versions" -ForegroundColor Red
        } else {
            Write-Host "  открываю $Place"
            Start-Process -FilePath $exe -ArgumentList "`"$Place`""
            Start-Sleep -Seconds 18
        }
    }
}

Write-Host "[2/3] VS Code" -ForegroundColor Cyan
$code = Get-Command code -ErrorAction SilentlyContinue
if ($code) {
    & code $ProjectRoot
    Write-Host "  папка проекта открыта"
} else {
    Write-Host "  code CLI не найден — открой папку вручную: $ProjectRoot" -ForegroundColor Yellow
}

Write-Host "[3/3] Мост и Studio" -ForegroundColor Cyan
$status = Join-Path $ProjectRoot "tools\status.js"
if (Test-Path $status) {
    & node $status
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  Studio пока не подключена. Открой плейс и включи MCP в Assistant," -ForegroundColor Yellow
        Write-Host "  затем повтори: node tools\status.js" -ForegroundColor Yellow
    }
} else {
    Write-Host "  нет $status" -ForegroundColor Red
}

Write-Host ""
Write-Host "Готово. Дальше в VS Code: панель Claude → 'Use the roblox-studio MCP tool bridge_status'." -ForegroundColor Green
Write-Host "Перед закрытием Studio не забудь Ctrl+S." -ForegroundColor Green
