# ============================================================
#  4-install-externals.ps1
#  외부 의존성 설치 스크립트
#  pyhub.mcptools, google-sheets MCP 서버 등을 설치합니다.
# ============================================================

param(
    [string]$RepoRoot = (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)),
    [switch]$SkipPause,
    [switch]$SkipPyhub,
    [switch]$SkipGoogleSheets
)

$ErrorActionPreference = 'Stop'

# 헬퍼 로드
. (Join-Path $RepoRoot 'scripts\lib\ui-helpers.ps1')

Write-Title "4단계: 외부 의존성 설치"

$totalSteps = 3
$currentStep = 1

# ════════════════════════════════════════════════════════════
# pyhub.mcptools 설치
# ════════════════════════════════════════════════════════════
if (-not $SkipPyhub) {
    Write-Step $currentStep $totalSteps "pyhub.mcptools 다운로드 중..."
    
    $pyhubDir = 'C:\pyhub.mcptools'
    $pyhubZipUrl = 'https://github.com/pyhub-kr/pyhub-mcptools/releases/download/latest/pyhub-mcptools-windows-x64.zip'
    $tempZip = "$env:TEMP\pyhub-mcptools.zip"
    
    try {
        if (Test-Path $pyhubDir) {
            Write-Info "pyhub.mcptools가 이미 설치되어 있습니다: $pyhubDir"
        } else {
            Write-Info "다운로드 중: $pyhubZipUrl"
            Invoke-WebRequest -Uri $pyhubZipUrl -OutFile $tempZip -UseBasicParsing
            Write-Success "다운로드 완료"
            
            Write-Info "압축 해제 중..."
            Expand-Archive -Path $tempZip -DestinationPath $pyhubDir -Force
            Write-Success "pyhub.mcptools 설치 완료: $pyhubDir"
            
            Remove-Item $tempZip -Force -ErrorAction SilentlyContinue
        }
    } catch {
        Write-Warning "pyhub.mcptools 설치 실패: $_"
        Write-Info "수동으로 설치하려면: https://github.com/pyhub-kr/pyhub-mcptools/releases"
    }
    
    $currentStep++
}

# ════════════════════════════════════════════════════════════
# Google Sheets MCP 서버 압축 해제
# ════════════════════════════════════════════════════════════
if (-not $SkipGoogleSheets) {
    Write-Step $currentStep $totalSteps "Google Sheets MCP 서버 설치 중..."
    
    $zipFile = Join-Path $RepoRoot 'snapshot\mcp-google-sheets-extended.zip'
    
    if (Test-Path $zipFile) {
        # 대안 드라이브 결정
        $targetDrive = if (Test-Path 'D:\') { 'D' } else { 'C' }
        $targetDir = "$($targetDrive):\ClaudeData\mcp-google-sheets-extended"
        
        Write-Info "대상: $targetDir"
        
        # 부모 디렉토리 생성
        $parentDir = Split-Path $targetDir -Parent
        if (-not (Test-Path $parentDir)) {
            New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
            Write-Info "디렉토리 생성: $parentDir"
        }
        
        # 기존 디렉토리 백업
        if (Test-Path $targetDir) {
            $backupDir = "$parentDir\mcp-google-sheets-extended.backup.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
            Move-Item -Path $targetDir -Destination $backupDir -Force
            Write-Info "기존 디렉토리 백업: $backupDir"
        }
        
        # 압축 해제
        Write-Info "압축 해제 중..."
        Expand-Archive -Path $zipFile -DestinationPath $targetDir -Force
        Write-Success "Google Sheets MCP 서버 설치 완료: $targetDir"
        
        # .credentials 디렉토리 생성 (비어있음)
        $credDir = Join-Path $targetDir '.credentials'
        if (-not (Test-Path $credDir)) {
            New-Item -ItemType Directory -Path $credDir -Force | Out-Null
            Write-Info ".credentials 디렉토리 생성 (서비스 계정 JSON을 여기에 배치해주세요)"
        }
    } else {
        Write-Warning "mcp-google-sheets-extended.zip을 찾을 수 없습니다: $zipFile"
        Write-Info "로컬에서 git pull을 실행하여 최신 상태로 동기화해주세요."
    }
    
    $currentStep++
}

# ════════════════════════════════════════════════════════════
# npm 글로벌 패키지 재설치
# ════════════════════════════════════════════════════════════
Write-Step $currentStep $totalSteps "npm 글로벌 패키지 재설치 중..."

$npmPackages = @(
    '@modelcontextprotocol/server-sequential-thinking',
    '@modelcontextprotocol/server-filesystem',
    'mcp-server-sqlite'
)

$npmList = npm list -g --depth 0 2>&1
foreach ($pkg in $npmPackages) {
    if ($npmList | Where-Object { $_ -match $pkg }) {
        Write-Info "$pkg: 이미 설치됨"
    } else {
        Write-Info "$pkg 설치 중..."
        try {
            npm install -g $pkg
            Write-Success "$pkg 설치 완료"
        } catch {
            Write-Warning "$pkg 설치 실패: $_"
        }
    }
}

Write-Host ""
Write-Success "외부 의존성 설치가 완료되었습니다."
Write-Info "다음: 5-verify.ps1을 실행하여 MCP 동작을 검증합니다."

if (-not $SkipPause) {
    Pause-ForUser "계속하려면 아무 키나 누르세요..."
}
