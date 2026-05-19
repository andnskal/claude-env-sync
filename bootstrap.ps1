# ============================================================
#  Claude Env Sync — Bootstrap (새 PC 원샷 셋업)
# ============================================================
#  사용법: PowerShell 관리자 권한 없이 일반 창에서 ↓ 한 줄 붙여넣기
#
#  irm https://raw.githubusercontent.com/<계정>/claude-env-sync/main/bootstrap.ps1 | iex
#
#  또는 옵션 지정:
#  & ([scriptblock]::Create((irm https://raw.githubusercontent.com/<계정>/claude-env-sync/main/bootstrap.ps1))) -RepoUrl "<계정>/claude-env-sync"
# ============================================================

param(
    [string]$RepoUrl   = '',
    [string]$WorkDir   = 'C:\dev'
)

$ErrorActionPreference = 'Stop'

Write-Host ""
Write-Host "╔═══════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║   Claude Env Sync — Bootstrap                         ║" -ForegroundColor Cyan
Write-Host "║   이 PC에 다른 PC의 Claude 환경을 복제합니다.         ║" -ForegroundColor Cyan
Write-Host "╚═══════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# ───────────────────────────────────────────────
# 1. winget 존재 확인
# ───────────────────────────────────────────────
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Host "✗ winget이 없습니다." -ForegroundColor Red
    Write-Host "  Microsoft Store에서 'App Installer'를 검색해 설치 후 다시 실행해주세요." -ForegroundColor Yellow
    exit 1
}

# ───────────────────────────────────────────────
# 2. git, gh(GitHub CLI) 설치
# ───────────────────────────────────────────────
Write-Host "[1/5] git, gh 설치 확인" -ForegroundColor Cyan

function Ensure-Tool {
    param([string]$Cmd, [string]$WingetId, [string]$Name)
    if (Get-Command $Cmd -ErrorAction SilentlyContinue) {
        Write-Host "  ✓ $Name 이미 설치됨" -ForegroundColor Green
    } else {
        Write-Host "  → $Name 설치 중..." -ForegroundColor Yellow
        winget install --id $WingetId --silent --accept-source-agreements --accept-package-agreements | Out-Null
        # PATH 갱신
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" +
                    [System.Environment]::GetEnvironmentVariable("Path","User")
        Write-Host "  ✓ $Name 설치 완료" -ForegroundColor Green
    }
}
Ensure-Tool -Cmd 'git' -WingetId 'Git.Git'      -Name 'Git'
Ensure-Tool -Cmd 'gh'  -WingetId 'GitHub.cli'   -Name 'GitHub CLI'

# ───────────────────────────────────────────────
# 3. GitHub 로그인
# ───────────────────────────────────────────────
Write-Host ""
Write-Host "[2/5] GitHub 로그인" -ForegroundColor Cyan
$authStatus = & gh auth status 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "  → 브라우저가 열리면서 GitHub 로그인 페이지가 표시됩니다." -ForegroundColor Yellow
    Write-Host "    화면에 표시되는 8자리 코드를 GitHub에 입력하세요." -ForegroundColor Yellow
    Write-Host ""
    & gh auth login --hostname github.com --git-protocol https --web
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  ✗ 로그인 실패. 다시 시도해주세요." -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "  ✓ 이미 로그인되어 있습니다." -ForegroundColor Green
}

# ───────────────────────────────────────────────
# 4. repo URL 결정
# ───────────────────────────────────────────────
Write-Host ""
Write-Host "[3/5] Repository 정보" -ForegroundColor Cyan
if (-not $RepoUrl) {
    $ghUser = (& gh api user --jq .login 2>$null)
    $default = "$ghUser/claude-env-sync"
    Write-Host "  Repository (기본값: $default)" -ForegroundColor Yellow
    $input = Read-Host "  > 다른 이름이면 입력, 그냥 엔터면 기본값 사용"
    $RepoUrl = if ($input) { $input } else { $default }
}
Write-Host "  ✓ 사용할 repo: $RepoUrl" -ForegroundColor Green

# ───────────────────────────────────────────────
# 5. clone
# ───────────────────────────────────────────────
Write-Host ""
Write-Host "[4/5] Repository clone" -ForegroundColor Cyan
if (-not (Test-Path $WorkDir)) {
    New-Item -ItemType Directory -Path $WorkDir -Force | Out-Null
    Write-Host "  → 작업 폴더 생성: $WorkDir" -ForegroundColor DarkGray
}
Set-Location $WorkDir

$repoName = ($RepoUrl -split '/')[-1]
$repoPath = Join-Path $WorkDir $repoName

if (Test-Path $repoPath) {
    Write-Host "  → 이미 존재함. git pull로 최신화..." -ForegroundColor Yellow
    Set-Location $repoPath
    & git pull
} else {
    & gh repo clone $RepoUrl
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  ✗ Clone 실패. repo 이름과 권한을 확인해주세요." -ForegroundColor Red
        exit 1
    }
    Set-Location $repoPath
}
Write-Host "  ✓ Clone 완료: $repoPath" -ForegroundColor Green

# ───────────────────────────────────────────────
# 6. import 실행
# ───────────────────────────────────────────────
Write-Host ""
Write-Host "[5/5] 환경 복원 시작" -ForegroundColor Cyan
Write-Host ""
if (-not (Test-Path '.\import.ps1')) {
    Write-Host "  ✗ import.ps1이 repo에 없습니다. 소스 PC에서 export 후 push했는지 확인하세요." -ForegroundColor Red
    exit 1
}

# 실행 정책 일시 우회
& powershell -ExecutionPolicy Bypass -NoProfile -File '.\import.ps1'

Write-Host ""
Write-Host "╔═══════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║   ✓ Bootstrap 완료                                    ║" -ForegroundColor Green
Write-Host "║                                                       ║" -ForegroundColor Green
Write-Host "║   이후 평소 동기화는 이 폴더의 .bat 파일을            ║" -ForegroundColor Green
Write-Host "║   더블클릭하시면 됩니다:                              ║" -ForegroundColor Green
Write-Host "║     • push.bat  — 이 PC 변경사항을 다른 PC로 보냄    ║" -ForegroundColor Green
Write-Host "║     • pull.bat  — 다른 PC 변경사항을 이 PC로 받음    ║" -ForegroundColor Green
Write-Host "╚═══════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
Write-Host "Repo 위치: $repoPath" -ForegroundColor Gray
