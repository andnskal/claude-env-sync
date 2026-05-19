# ============================================================
# UI Helper Functions
# 진행률 표시, 선택지 유도, 색상 메시지 등
# ============================================================

function Write-Title {
    param([string]$Message)
    Write-Host ""
    Write-Host "╔══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║ $Message" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
}

function Write-Step {
    param([int]$Step, [int]$Total, [string]$Message)
    $pct = [math]::Round(($Step / $Total) * 100)
    $bar = "█" * [math]::Round($pct / 5) + "░" * (20 - [math]::Round($pct / 5))
    Write-Host "[$Step/$Total] $Message" -ForegroundColor Green
    Write-Host "  [$bar] $pct%" -ForegroundColor Gray
}

function Write-Success {
    param([string]$Message)
    Write-Host "✓ $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "⚠ $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "✗ $Message" -ForegroundColor Red
}

function Write-Info {
    param([string]$Message)
    Write-Host "ℹ $Message" -ForegroundColor Cyan
}

function Ask-YesNo {
    param([string]$Question)
    while ($true) {
        Write-Host "$Question (Y/N): " -ForegroundColor Cyan -NoNewline
        $answer = Read-Host
        if ($answer -match '^[yY]$') { return $true }
        if ($answer -match '^[nN]$') { return $false }
        Write-Host "Y 또는 N을 입력해주세요." -ForegroundColor Yellow
    }
}

function Show-Table {
    param([object[]]$Data, [string[]]$Headers)
    if (-not $Data -or $Data.Count -eq 0) {
        Write-Host "  (없음)" -ForegroundColor Gray
        return
    }
    $maxLengths = @{}
    foreach ($h in $Headers) { $maxLengths[$h] = $h.Length }
    foreach ($row in $Data) {
        foreach ($h in $Headers) {
            $val = $row.$h | Out-String | ForEach-Object Trim
            if ($val.Length -gt $maxLengths[$h]) { $maxLengths[$h] = $val.Length }
        }
    }
    $header = ($Headers | ForEach-Object { "{0,-$($maxLengths[$_])}" -f $_ }) -join " | "
    Write-Host "  $header" -ForegroundColor Green
    Write-Host ("  " + ("-" * ($header.Length - 2))) -ForegroundColor Gray
    foreach ($row in $Data) {
        $line = ($Headers | ForEach-Object { "{0,-$($maxLengths[$_])}" -f $row.$_ }) -join " | "
        Write-Host "  $line" -ForegroundColor White
    }
}

function Pause-ForUser {
    param([string]$Message = "계속하려면 아무 키나 누르세요...")
    Write-Host ""
    Write-Host $Message -ForegroundColor Yellow
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}
