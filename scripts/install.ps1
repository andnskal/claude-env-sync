# ============================================================
#  install.ps1
#  진입점 스크립트 (사용자가 한 줄로 호출)
#  모든 설정 단계를 순차적으로 실행합니다.
# ============================================================

[CmdletBinding()]
param(
    [switch]$SkipGit,
    [switch]$SkipGitHub,
    [switch]$SkipClone,
    [switch]$Diagnose,
    [switch]$BuildMapping,
    [switch]$ApplyMapping,
    [switch]$InstallExternals,
    [switch]$Verify
)

$ErrorActionPreference = 'Stop'
$scriptPath = $PSScriptRoot
$repoPath = 'C:\dev\claude-env-sync'

# ════════════════════════════════════════════════════════════
# 메뉴: 특정 단계만 실행하는 경우
# ════════════════════════════════════════════════════════════
if ($Diagnose -or $BuildMapping -or $ApplyMapping -or $InstallExternals -or $Verify) {
    if ($Diagnose) {
        & "$repoPath\scripts\1-diagnose.ps1" -SkipPause
    }
    if ($BuildMapping) {
        & "$repoPath\scripts\2-build-mapping.ps1" -SkipPause
    }
    if ($ApplyMapping) {
        & "$repoPath\scripts\3-apply-mapping.ps1" -SkipPause
    }
    if ($InstallExternals) {
        & "$repoPath\scripts\4-install-externals.ps1" -SkipPause
    }
    if ($Verify) {
        & "$repoPath\scripts\5-verify.ps1" -SkipPause
    }
    exit 0
}

# ════════════════════════════════════════════════════════════
# 일반 흐름: 처음부터 끝까지
# ════════════════════════════════════════════════════════════

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  Claude Environment Sync - 설치 마법사                     ║" -ForegroundColor Cyan
Write-Host "║  이 스크립트는 다음 단계를 자동으로 진행합니다:            ║" -ForegroundColor Cyan
Write-Host "║  1. 시스템 환경 진단                                       ║" -ForegroundColor Cyan
Write-Host "║  2. 경로 매핑 테이블 생성                                  ║" -ForegroundColor Cyan
Write-Host "║  3. 경로 매핑 적용                                         ║" -ForegroundColor Cyan
Write-Host "║  4. 외부 의존성 설치 (pyhub, google-sheets)                ║" -ForegroundColor Cyan
Write-Host "║  5. MCP 검증                                               ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# ════════════════════════════════════════════════════════════
# 1. Repo 확인 또는 clone
# ════════════════════════════════════════════════════════════
if (-not (Test-Path "$repoPath\.git")) {
    if ($SkipClone) {
        Write-Host "✗ Repo가 없고 -SkipClone이 지정되었습니다. 종료합니다." -ForegroundColor Red
        exit 1
    }
    
    Write-Host "Repo를 $repoPath에 clone합니다..." -ForegroundColor Green
    
    # Git 확인
    if (-not $SkipGit) {
        . (Join-Path $scriptPath '\scripts\lib\git-helpers.ps1')
        if (-not (Test-GitInstalled)) {
            if (-not (Install-Git)) {
                Write-Host "✗ Git 설치 실패. 수동으로 설치해주세요." -ForegroundColor Red
                exit 1
            }
        }
    }
    
    # GitHub CLI 로그인
    if (-not $SkipGitHub) {
        $gitPath = 'C:\Program Files\Git\cmd\git.exe'
        Write-Host "GitHub CLI를 사용하여 로그인합니다..." -ForegroundColor Green
        gh auth login --hostname github.com --git-protocol https --web
    }
    
    # Clone
    $parentDir = Split-Path $repoPath -Parent
    if (-not (Test-Path $parentDir)) {
        New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
    }
    gh repo clone andnskal/claude-env-sync $repoPath
}

Write-Host "✓ Repo 준비 완료" -ForegroundColor Green
Write-Host ""

# ════════════════════════════════════════════════════════════
# 2. 모든 단계 실행
# ════════════════════════════════════════════════════════════
$steps = @(
    @{ 'File' = '1-diagnose.ps1'; 'Name' = '시스템 진단' },
    @{ 'File' = '2-build-mapping.ps1'; 'Name' = '경로 매핑 테이블 생성' },
    @{ 'File' = '3-apply-mapping.ps1'; 'Name' = '경로 매핑 적용' },
    @{ 'File' = '4-install-externals.ps1'; 'Name' = '외부 의존성 설치' },
    @{ 'File' = '5-verify.ps1'; 'Name' = 'MCP 검증' }
)

foreach ($step in $steps) {
    $scriptFile = Join-Path $repoPath "scripts\$($step['File'])"
    Write-Host ""
    Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "단계: $($step['Name'])" -ForegroundColor Cyan
    Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    
    if (Test-Path $scriptFile) {
        try {
            & $scriptFile -SkipPause
        } catch {
            Write-Host "✗ 단계 실패: $_" -ForegroundColor Red
            Write-Host ""
            Write-Host "계속하려면 아무 키나 누르세요..." -ForegroundColor Yellow
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
    } else {
        Write-Host "✗ 스크립트를 찾을 수 없습니다: $scriptFile" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host "✓ 모든 설정 단계가 완료되었습니다!" -ForegroundColor Green
Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host ""
Write-Host "다음 단계:" -ForegroundColor Cyan
Write-Host "  1. Claude Desktop을 완전히 종료하세요 (트레이 아이콘에서 종료)"
Write-Host "  2. Claude Desktop을 다시 실행하세요"
Write-Host "  3. 우측 하단 🔌 아이콘으로 MCP 상태를 확인하세요"
Write-Host "  4. 모든 MCP가 녹색으로 표시되면 완료입니다!"
Write-Host ""
