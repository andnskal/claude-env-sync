# ============================================================
#  Claude Env Sync — Init (집 PC 첫 셋업 자동화)
# ============================================================
#  목적: GitHub repo 자동 생성 + 환경 백업 + 첫 push
#       init.bat 더블클릭 → 이 스크립트 자동 실행
#
#  진행 과정:
#   1. winget으로 git, gh 자동 설치
#   2. gh로 GitHub 로그인 (브라우저)
#   3. private repo 자동 생성
#   4. C:\dev\claude-env-sync 에 clone
#   5. 받은 파일들 자동 복사
#   6. export.ps1 실행 (환경 백업)
#   7. git commit + push
# ============================================================

param(
    [string]$RepoName = 'claude-env-sync',
    [string]$WorkDir  = 'C:\dev'
)

$ErrorActionPreference = 'Stop'
$SourceDir = $PSScriptRoot

Write-Host ""
Write-Host "╔═══════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║   Claude Env Sync — INIT (첫 셋업 자동화)             ║" -ForegroundColor Cyan
Write-Host "║   이 PC를 다른 PC로 복제할 수 있는 상태로 만듭니다.   ║" -ForegroundColor Cyan
Write-Host "╚═══════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# ───────────────────────────────────────────────
# Step 1. winget 확인
# ───────────────────────────────────────────────
Write-Host "[1/7] 시스템 도구 확인" -ForegroundColor Cyan
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Host "  ✗ winget이 없습니다." -ForegroundColor Red
    Write-Host "    Microsoft Store에서 'App Installer'를 설치 후 다시 시도하세요." -ForegroundColor Yellow
    Write-Host ""
    Read-Host "엔터를 누르면 종료"
    exit 1
}
Write-Host "  ✓ winget 확인" -ForegroundColor Green

# ───────────────────────────────────────────────
# Step 2. git, gh 설치
# ───────────────────────────────────────────────
function Ensure-Tool {
    param([string]$Cmd, [string]$WingetId, [string]$Name)
    if (Get-Command $Cmd -ErrorAction SilentlyContinue) {
        Write-Host "  ✓ $Name 이미 설치됨" -ForegroundColor Green
    } else {
        Write-Host "  → $Name 설치 중... (1-2분 소요)" -ForegroundColor Yellow
        winget install --id $WingetId --silent --accept-source-agreements --accept-package-agreements | Out-Null
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" +
                    [System.Environment]::GetEnvironmentVariable("Path","User")
        if (-not (Get-Command $Cmd -ErrorAction SilentlyContinue)) {
            Write-Host "  ⚠ $Name PATH 인식 실패 — PowerShell을 새로 열고 다시 시도하세요." -ForegroundColor Red
            Read-Host "엔터를 누르면 종료"
            exit 1
        }
        Write-Host "  ✓ $Name 설치 완료" -ForegroundColor Green
    }
}
Ensure-Tool -Cmd 'git' -WingetId 'Git.Git'    -Name 'Git'
Ensure-Tool -Cmd 'gh'  -WingetId 'GitHub.cli' -Name 'GitHub CLI'

# ───────────────────────────────────────────────
# Step 3. GitHub 로그인
# ───────────────────────────────────────────────
Write-Host ""
Write-Host "[2/7] GitHub 로그인" -ForegroundColor Cyan
& gh auth status 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "  → 잠시 후 브라우저가 열리며 8자리 코드가 표시됩니다." -ForegroundColor Yellow
    Write-Host "    화면의 코드를 브라우저 GitHub 페이지에 입력하세요." -ForegroundColor Yellow
    Write-Host ""
    & gh auth login --hostname github.com --git-protocol https --web
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  ✗ GitHub 로그인 실패" -ForegroundColor Red
        Read-Host "엔터를 누르면 종료"
        exit 1
    }
} else {
    Write-Host "  ✓ 이미 로그인되어 있음" -ForegroundColor Green
}

# 사용자 ID 가져오기
$ghUser = (& gh api user --jq .login 2>$null).Trim()
if (-not $ghUser) {
    Write-Host "  ✗ GitHub 사용자 정보를 가져오지 못했습니다." -ForegroundColor Red
    Read-Host "엔터를 누르면 종료"
    exit 1
}
Write-Host "  ✓ 로그인됨: $ghUser" -ForegroundColor Green
$repoFullName = "$ghUser/$RepoName"

# ───────────────────────────────────────────────
# Step 4. Repo 생성 또는 확인
# ───────────────────────────────────────────────
Write-Host ""
Write-Host "[3/7] GitHub repository 준비" -ForegroundColor Cyan
& gh repo view $repoFullName 2>$null | Out-Null
$repoExists = ($LASTEXITCODE -eq 0)

if ($repoExists) {
    Write-Host "  ✓ 이미 존재하는 repo 사용: $repoFullName" -ForegroundColor Green
} else {
    Write-Host "  → private repo 생성 중: $repoFullName" -ForegroundColor Yellow
    & gh repo create $repoFullName --private --description "Claude 환경 동기화 (자동 생성)" 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  ✗ repo 생성 실패" -ForegroundColor Red
        Read-Host "엔터를 누르면 종료"
        exit 1
    }
    Write-Host "  ✓ repo 생성 완료" -ForegroundColor Green
}

# ───────────────────────────────────────────────
# Step 5. Repo clone
# ───────────────────────────────────────────────
Write-Host ""
Write-Host "[4/7] 작업 폴더에 clone" -ForegroundColor Cyan
if (-not (Test-Path $WorkDir)) {
    New-Item -ItemType Directory -Path $WorkDir -Force | Out-Null
    Write-Host "  → 작업 폴더 생성: $WorkDir" -ForegroundColor DarkGray
}
$repoPath = Join-Path $WorkDir $RepoName
if (Test-Path (Join-Path $repoPath '.git')) {
    Write-Host "  → 이미 clone되어 있음. git pull로 최신화..." -ForegroundColor Yellow
    Set-Location $repoPath
    & git pull 2>&1 | Out-Null
} else {
    if (Test-Path $repoPath) { Remove-Item $repoPath -Recurse -Force }
    Set-Location $WorkDir
    & gh repo clone $repoFullName 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  ✗ clone 실패" -ForegroundColor Red
        Read-Host "엔터를 누르면 종료"
        exit 1
    }
    Set-Location $repoPath
}
Write-Host "  ✓ 작업 폴더: $repoPath" -ForegroundColor Green

# ───────────────────────────────────────────────
# Step 6. 받은 파일 복사 (init 자체는 제외)
# ───────────────────────────────────────────────
Write-Host ""
Write-Host "[5/7] 스크립트 파일 복사" -ForegroundColor Cyan
$filesToCopy = @(
    'bootstrap.ps1','export.ps1','import.ps1',
    'push.bat','pull.bat','README.md','.gitignore'
)
$copied = 0
foreach ($f in $filesToCopy) {
    $src = Join-Path $SourceDir $f
    if (Test-Path $src) {
        Copy-Item $src (Join-Path $repoPath $f) -Force
        $copied++
    } else {
        Write-Host "  ⚠ $f 없음 (건너뜀)" -ForegroundColor DarkYellow
    }
}
Write-Host "  ✓ $copied 개 파일 복사됨" -ForegroundColor Green

# ───────────────────────────────────────────────
# Step 7. 첫 export + push
# ───────────────────────────────────────────────
Write-Host ""
Write-Host "[6/7] 환경 백업 실행 (.\export.ps1)" -ForegroundColor Cyan
Write-Host ""
& powershell -ExecutionPolicy Bypass -NoProfile -File '.\export.ps1'
if ($LASTEXITCODE -ne 0) {
    Write-Host "  ✗ export 실패" -ForegroundColor Red
    Read-Host "엔터를 누르면 종료"
    exit 1
}

Write-Host ""
Write-Host "[7/7] GitHub에 push" -ForegroundColor Cyan
& git add . 2>&1 | Out-Null
$gitStatus = & git status --porcelain
if ($gitStatus) {
    & git commit -m "초기 환경 백업 $(Get-Date -Format 'yyyy-MM-dd HH:mm')" 2>&1 | Out-Null
    # 첫 push는 upstream 설정 필요
    $branch = (& git branch --show-current).Trim()
    & git push -u origin $branch 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✓ push 완료" -ForegroundColor Green
    } else {
        Write-Host "  ⚠ push 실패 — 수동으로 'git push -u origin $branch' 실행 필요" -ForegroundColor DarkYellow
    }
} else {
    Write-Host "  → 변경사항 없음 (push 생략)" -ForegroundColor DarkGray
}

# ───────────────────────────────────────────────
# 완료
# ───────────────────────────────────────────────
$bootstrapUrl = "https://raw.githubusercontent.com/$repoFullName/main/bootstrap.ps1"
Write-Host ""
Write-Host "╔═══════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║   ✓ 첫 셋업 완료!                                     ║" -ForegroundColor Green
Write-Host "╚═══════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
Write-Host "📂 Repo 위치:" -ForegroundColor White
Write-Host "   $repoPath" -ForegroundColor Gray
Write-Host ""
Write-Host "🔗 GitHub:" -ForegroundColor White
Write-Host "   https://github.com/$repoFullName" -ForegroundColor Gray
Write-Host ""
Write-Host "💻 다른 PC (회사 PC 등) 에서 복제하기:" -ForegroundColor White
Write-Host "   PowerShell 열고 ↓ 한 줄 붙여넣기" -ForegroundColor Gray
Write-Host ""
Write-Host "   irm $bootstrapUrl | iex" -ForegroundColor Yellow
Write-Host ""
Write-Host "📋 이 명령어가 자동으로 클립보드에 복사되었습니다." -ForegroundColor White
"irm $bootstrapUrl | iex" | Set-Clipboard
Write-Host ""
Write-Host "🔄 이후 평소 사용:" -ForegroundColor White
Write-Host "   • push.bat 더블클릭 — 이 PC 변경사항을 다른 PC로" -ForegroundColor Gray
Write-Host "   • pull.bat 더블클릭 — 다른 PC 변경사항을 이 PC로" -ForegroundColor Gray
Write-Host ""
Read-Host "엔터를 누르면 종료"
