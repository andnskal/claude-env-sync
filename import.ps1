# ============================================================
#  Claude 환경 Import 스크립트
# ============================================================
#  목적: snapshot/ 에 들어있는 백업을 현재 PC에 복원
#        + 필요한 런타임 자동 설치 (Python, Node, Git, uv)
#        + 사용자명/API 키 자동 치환
#
#  실행: PowerShell에서  .\import.ps1
#  옵션: -SkipInstall   런타임 자동 설치 건너뛰기
#        -SkipPip       Python 패키지 복원 건너뛰기
#        -SkipNpm       npm 글로벌 패키지 복원 건너뛰기
#        -DryRun        실제 파일 안 만들고 어떤 작업할지만 출력
# ============================================================

param(
    [switch]$SkipInstall,
    [switch]$SkipPip,
    [switch]$SkipNpm,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$RepoRoot    = $PSScriptRoot
$Snapshot    = Join-Path $RepoRoot 'snapshot'
$BackupDir   = Join-Path $RepoRoot ("backup\" + (Get-Date -Format 'yyyyMMdd-HHmmss'))
$CurrentUser = $env:USERNAME

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Claude Environment Import" -ForegroundColor Cyan
Write-Host "  대상 사용자: $CurrentUser | 컴퓨터: $env:COMPUTERNAME" -ForegroundColor Gray
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# snapshot 존재 확인
if (-not (Test-Path $Snapshot)) {
    Write-Host "✗ snapshot/ 폴더가 없습니다. 먼저 다른 PC에서 export.ps1을 실행 후 push했는지 확인하세요." -ForegroundColor Red
    exit 1
}

# manifest 읽어서 원본 PC 정보 표시
$manifestPath = Join-Path $Snapshot 'manifest.json'
if (Test-Path $manifestPath) {
    $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
    Write-Host "📦 백업 정보:" -ForegroundColor White
    Write-Host "   원본 PC: $($manifest.sourceUser)@$($manifest.sourceHost)" -ForegroundColor Gray
    Write-Host "   백업 일시: $($manifest.exportedAt)" -ForegroundColor Gray
    Write-Host "   비밀 키: $($manifest.secretsCount) 개" -ForegroundColor Gray
    Write-Host ""
}

# ════════════════════════════════════════════════
#  STEP 1. Preflight — 런타임 환경 점검
# ════════════════════════════════════════════════
Write-Host "═══ STEP 1. 환경 사전점검 ═══" -ForegroundColor Cyan

function Test-Command {
    param([string]$Name)
    $null = Get-Command $Name -ErrorAction SilentlyContinue
    return $?
}

function Install-WithWinget {
    param([string]$WingetId, [string]$DisplayName)
    Write-Host "  → $DisplayName 설치 중 (winget install $WingetId)..." -ForegroundColor Yellow
    if ($DryRun) { Write-Host "    [DryRun] 실제 설치 건너뜀" -ForegroundColor Magenta; return }
    & winget install --id $WingetId --silent --accept-source-agreements --accept-package-agreements
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  ✗ $DisplayName 설치 실패. 수동으로 설치해주세요." -ForegroundColor Red
    } else {
        Write-Host "  ✓ $DisplayName 설치 완료" -ForegroundColor Green
    }
}

$Required = @(
    @{ Cmd='python'; WingetId='Python.Python.3.12';   Name='Python 3.12' }
    @{ Cmd='node';   WingetId='OpenJS.NodeJS.LTS';    Name='Node.js LTS'  }
    @{ Cmd='npm';    WingetId='OpenJS.NodeJS.LTS';    Name='npm (Node 포함)' }
    @{ Cmd='git';    WingetId='Git.Git';              Name='Git' }
    @{ Cmd='uv';     WingetId='astral-sh.uv';         Name='uv (Python 패키지 매니저)' }
)

$Missing = @()
foreach ($r in $Required) {
    if (Test-Command $r.Cmd) {
        $ver = & $r.Cmd --version 2>&1 | Select-Object -First 1
        Write-Host "  ✓ $($r.Name)  ($ver)" -ForegroundColor Green
    } else {
        Write-Host "  ✗ $($r.Name)  — 누락" -ForegroundColor Red
        $Missing += $r
    }
}

if ($Missing.Count -gt 0 -and -not $SkipInstall) {
    Write-Host ""
    Write-Host "  누락된 $($Missing.Count) 개 항목을 winget으로 설치하시겠습니까? (Y/N)" -ForegroundColor Yellow
    $ans = Read-Host "  >"
    if ($ans -match '^[Yy]') {
        if (-not (Test-Command 'winget')) {
            Write-Host "  ✗ winget이 없습니다. Microsoft Store에서 'App Installer'를 먼저 설치하세요." -ForegroundColor Red
            exit 1
        }
        foreach ($m in $Missing) { Install-WithWinget -WingetId $m.WingetId -DisplayName $m.Name }
        Write-Host ""
        Write-Host "  ⚠  설치 후에는 PowerShell을 새로 열어야 PATH가 갱신됩니다." -ForegroundColor Yellow
        Write-Host "     이 스크립트를 새 창에서 다시 실행해주세요." -ForegroundColor Yellow
        exit 0
    } else {
        Write-Host "  → 설치 건너뛰고 계속 진행합니다 (일부 MCP가 동작하지 않을 수 있음)" -ForegroundColor DarkYellow
    }
} elseif ($Missing.Count -gt 0) {
    Write-Host "  → -SkipInstall 모드 — 누락 항목 무시" -ForegroundColor DarkYellow
}
Write-Host ""

# ════════════════════════════════════════════════
#  STEP 2. 백업 폴더 생성 (덮어쓰기 전 안전망)
# ════════════════════════════════════════════════
Write-Host "═══ STEP 2. 기존 설정 백업 ═══" -ForegroundColor Cyan
if (-not $DryRun) { New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null }

$BackupTargets = @(
    Join-Path $env:APPDATA 'Claude\claude_desktop_config.json'
    Join-Path $env:USERPROFILE '.claude\settings.json'
    Join-Path $env:USERPROFILE '.claude\CLAUDE.md'
    Join-Path $env:USERPROFILE '.claude.json'
)
foreach ($p in $BackupTargets) {
    if (Test-Path $p) {
        $dst = Join-Path $BackupDir (Split-Path $p -Leaf)
        if (-not $DryRun) { Copy-Item $p $dst -Force }
        Write-Host "  ✓ 백업: $(Split-Path $p -Leaf)" -ForegroundColor Green
    }
}
$SkillsTarget = Join-Path $env:USERPROFILE '.claude\skills'
if (Test-Path $SkillsTarget) {
    if (-not $DryRun) { Copy-Item $SkillsTarget (Join-Path $BackupDir 'skills') -Recurse -Force }
    Write-Host "  ✓ 백업: skills/ 폴더" -ForegroundColor Green
}
Write-Host "  → 백업 위치: $BackupDir" -ForegroundColor Gray
Write-Host ""

# ════════════════════════════════════════════════
#  STEP 3. API 키 입력 받기 (.env 생성)
# ════════════════════════════════════════════════
Write-Host "═══ STEP 3. API 키 / 토큰 입력 ═══" -ForegroundColor Cyan
$EnvExample = Join-Path $RepoRoot '.env.example'
$EnvFile    = Join-Path $RepoRoot '.env'
$Secrets    = @{}

if (Test-Path $EnvExample) {
    $lines = Get-Content $EnvExample
    $currentComment = ''
    foreach ($line in $lines) {
        if ($line -match '^# \[(.+?)\] (.+)$') {
            $currentComment = "$($matches[1]) - $($matches[2])"
        } elseif ($line -match '^(__SECRET_.+__)=') {
            $key = $matches[1]
            Write-Host ""
            Write-Host "  🔑 $currentComment" -ForegroundColor Yellow
            Write-Host "     (입력 시 화면에 표시되지 않음. 비워두면 자리표시자가 유지됩니다.)" -ForegroundColor DarkGray
            $secure = Read-Host "     값" -AsSecureString
            $plain = [System.Net.NetworkCredential]::new('', $secure).Password
            if ($plain) { $Secrets[$key] = $plain }
            $currentComment = ''
        }
    }
    # .env 파일로 저장 (로컬용, 절대 커밋 안 됨 — .gitignore 적용)
    if ($Secrets.Count -gt 0 -and -not $DryRun) {
        $envOut = @("# Generated $(Get-Date) — DO NOT COMMIT")
        foreach ($k in $Secrets.Keys) { $envOut += "$k=$($Secrets[$k])" }
        $envOut | Set-Content -Path $EnvFile -Encoding UTF8
        Write-Host ""
        Write-Host "  ✓ .env 파일 생성 완료 ($($Secrets.Count)개 키, .gitignore로 보호됨)" -ForegroundColor Green
    } elseif ($Secrets.Count -eq 0) {
        Write-Host "  → 입력된 키 없음. 자리표시자가 그대로 유지됩니다." -ForegroundColor DarkYellow
    }
} else {
    Write-Host "  → .env.example 없음 (건너뜀)" -ForegroundColor DarkYellow
}
Write-Host ""

# ════════════════════════════════════════════════
#  STEP 4. 자리표시자 치환 + Claude Desktop config 설치
# ════════════════════════════════════════════════
Write-Host "═══ STEP 4. Claude Desktop config 복원 ═══" -ForegroundColor Cyan

function Resolve-Template {
    param([string]$Text, [string]$UserName, [hashtable]$SecretMap)
    $Text = $Text -replace '__USERNAME__', $UserName
    if ($SecretMap) {
        foreach ($k in $SecretMap.Keys) {
            # JSON 문자열 안의 따옴표 이스케이프
            $safe = $SecretMap[$k] -replace '\\', '\\' -replace '"', '\"'
            $Text = $Text -replace [regex]::Escape($k), $safe
        }
    }
    return $Text
}

$DesktopTemplate = Join-Path $Snapshot 'claude_desktop_config.template.json'
$DesktopTarget   = Join-Path $env:APPDATA 'Claude\claude_desktop_config.json'

if (Test-Path $DesktopTemplate) {
    $raw = Get-Content $DesktopTemplate -Raw -Encoding UTF8
    $resolved = Resolve-Template -Text $raw -UserName $CurrentUser -SecretMap $Secrets

    # JSON 유효성 검증
    try { $null = $resolved | ConvertFrom-Json }
    catch {
        Write-Host "  ✗ 치환 결과가 유효한 JSON이 아닙니다: $_" -ForegroundColor Red
        exit 1
    }

    $targetDir = Split-Path $DesktopTarget -Parent
    if (-not (Test-Path $targetDir)) {
        if (-not $DryRun) { New-Item -ItemType Directory -Path $targetDir -Force | Out-Null }
    }
    if (-not $DryRun) { $resolved | Set-Content -Path $DesktopTarget -Encoding UTF8 }
    Write-Host "  ✓ $DesktopTarget" -ForegroundColor Green
} else {
    Write-Host "  → Desktop config 템플릿 없음 (건너뜀)" -ForegroundColor DarkYellow
}
Write-Host ""

# ════════════════════════════════════════════════
#  STEP 5. Claude Code 설정 + Skills 복원
# ════════════════════════════════════════════════
Write-Host "═══ STEP 5. Claude Code 복원 ═══" -ForegroundColor Cyan
$ClaudeHome = Join-Path $env:USERPROFILE '.claude'
if (-not (Test-Path $ClaudeHome)) {
    if (-not $DryRun) { New-Item -ItemType Directory -Path $ClaudeHome -Force | Out-Null }
}

$ccRestore = @(
    @{ Src='claude-code-settings.json'; Dst=(Join-Path $ClaudeHome 'settings.json') }
    @{ Src='CLAUDE.md';                  Dst=(Join-Path $ClaudeHome 'CLAUDE.md') }
    @{ Src='claude-code-mcp.template.json'; Dst=(Join-Path $env:USERPROFILE '.claude.json') }
)
foreach ($r in $ccRestore) {
    $srcPath = Join-Path $Snapshot $r.Src
    if (Test-Path $srcPath) {
        $content = Get-Content $srcPath -Raw -Encoding UTF8
        $content = Resolve-Template -Text $content -UserName $CurrentUser -SecretMap $Secrets
        if (-not $DryRun) { $content | Set-Content -Path $r.Dst -Encoding UTF8 }
        Write-Host "  ✓ $(Split-Path $r.Dst -Leaf)" -ForegroundColor Green
    }
}

# Skills 폴더
$SkillsSrc = Join-Path $Snapshot 'skills'
$SkillsDst = Join-Path $ClaudeHome 'skills'
if (Test-Path $SkillsSrc) {
    if ((Test-Path $SkillsDst) -and (-not $DryRun)) {
        Remove-Item $SkillsDst -Recurse -Force
    }
    if (-not $DryRun) { Copy-Item $SkillsSrc $SkillsDst -Recurse -Force }
    $count = (Get-ChildItem $SkillsSrc -Directory).Count
    Write-Host "  ✓ skills/ 복원 ($count 개 스킬)" -ForegroundColor Green
}
Write-Host ""

# ════════════════════════════════════════════════
#  STEP 6. Python / npm 패키지 일괄 설치
# ════════════════════════════════════════════════
Write-Host "═══ STEP 6. 패키지 복원 ═══" -ForegroundColor Cyan

$PipFile = Join-Path $Snapshot 'pip-freeze.txt'
if (-not $SkipPip -and (Test-Path $PipFile) -and (Test-Command 'pip')) {
    Write-Host "  → pip install -r pip-freeze.txt 실행 (시간 소요)..." -ForegroundColor Yellow
    if (-not $DryRun) {
        & pip install -r $PipFile --quiet
        Write-Host "  ✓ Python 패키지 복원 완료" -ForegroundColor Green
    }
} else {
    Write-Host "  → pip 복원 건너뜀" -ForegroundColor DarkGray
}

$NpmFile = Join-Path $Snapshot 'npm-globals.txt'
if (-not $SkipNpm -and (Test-Path $NpmFile) -and (Test-Command 'npm')) {
    $pkgs = Get-Content $NpmFile | Where-Object { $_ -and $_ -notmatch '^npm$' }
    if ($pkgs) {
        Write-Host "  → npm 글로벌 패키지 $($pkgs.Count) 개 설치 중..." -ForegroundColor Yellow
        if (-not $DryRun) {
            foreach ($p in $pkgs) {
                Write-Host "    • $p" -ForegroundColor DarkGray
                & npm install -g $p --silent 2>&1 | Out-Null
            }
            Write-Host "  ✓ npm 글로벌 패키지 복원 완료" -ForegroundColor Green
        }
    }
} else {
    Write-Host "  → npm 복원 건너뜀" -ForegroundColor DarkGray
}
Write-Host ""

# ════════════════════════════════════════════════
#  STEP 7. 검증
# ════════════════════════════════════════════════
Write-Host "═══ STEP 7. 검증 ═══" -ForegroundColor Cyan
$Checks = @(
    @{ Path=$DesktopTarget; Name='Claude Desktop config' }
    @{ Path=(Join-Path $ClaudeHome 'skills'); Name='Skills 폴더' }
    @{ Path=(Join-Path $ClaudeHome 'settings.json'); Name='Claude Code settings' }
)
$ok = $true
foreach ($c in $Checks) {
    if (Test-Path $c.Path) {
        Write-Host "  ✓ $($c.Name)" -ForegroundColor Green
    } else {
        Write-Host "  ⚠ $($c.Name) — 누락 (원본에 없었을 수 있음)" -ForegroundColor DarkYellow
    }
}

# config JSON 유효성 재검증
if (Test-Path $DesktopTarget) {
    try {
        $cfg = Get-Content $DesktopTarget -Raw | ConvertFrom-Json
        $mcpCount = ($cfg.mcpServers.PSObject.Properties).Count
        Write-Host "  ✓ MCP 서버 $mcpCount 개 인식됨" -ForegroundColor Green
    } catch {
        Write-Host "  ✗ config JSON 파싱 실패: $_" -ForegroundColor Red
        $ok = $false
    }
}

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
if ($ok) {
    Write-Host "  ✓ Import 완료" -ForegroundColor Green
} else {
    Write-Host "  ⚠ Import 완료 — 일부 문제 발견" -ForegroundColor Yellow
}
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "다음 단계:" -ForegroundColor White
Write-Host "  1. Claude Desktop을 완전히 종료 후 재시작" -ForegroundColor Gray
Write-Host "  2. (Claude Code 사용 시) 새 PowerShell 창에서 'claude' 실행하여 동작 확인" -ForegroundColor Gray
Write-Host "  3. 문제 발생 시 백업에서 복원:" -ForegroundColor Gray
Write-Host "     $BackupDir" -ForegroundColor DarkGray
Write-Host ""
