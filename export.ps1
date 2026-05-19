# ============================================================
#  Claude 환경 Export 스크립트
# ============================================================
#  목적: 현재 PC의 Claude Desktop + Claude Code 설정을
#        GitHub repo에 커밋 가능한 형태로 백업
#
#  실행: PowerShell에서  .\export.ps1
#  옵션: -DryRun       실제 파일 안 만들고 어떤 작업할지만 출력
#        -SkipPip      pip freeze 건너뛰기
#        -SkipNpm      npm 글로벌 목록 건너뛰기
# ============================================================

param(
    [switch]$DryRun,
    [switch]$SkipPip,
    [switch]$SkipNpm
)

$ErrorActionPreference = 'Stop'
$RepoRoot   = $PSScriptRoot
$Snapshot   = Join-Path $RepoRoot 'snapshot'
$CurrentUser = $env:USERNAME

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Claude Environment Export" -ForegroundColor Cyan
Write-Host "  사용자: $CurrentUser | 컴퓨터: $env:COMPUTERNAME" -ForegroundColor Gray
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# ────────────────────────────────────────────────
# 0. snapshot 폴더 준비
# ────────────────────────────────────────────────
if (-not $DryRun) {
    if (Test-Path $Snapshot) { Remove-Item $Snapshot -Recurse -Force }
    New-Item -ItemType Directory -Path $Snapshot | Out-Null
}
Write-Host "[0/7] snapshot/ 폴더 초기화 완료" -ForegroundColor Green

# ────────────────────────────────────────────────
# 헬퍼: 경로/토큰 자리표시자 치환
# ────────────────────────────────────────────────
function Convert-ToTemplate {
    param([string]$Text, [string]$UserName)
    # 사용자명 → __USERNAME__
    $Text = $Text -replace [regex]::Escape("\Users\$UserName\"), '\Users\__USERNAME__\'
    $Text = $Text -replace [regex]::Escape("/Users/$UserName/"), '/Users/__USERNAME__/'
    $Text = $Text -replace [regex]::Escape("C:\Users\$UserName"), 'C:\Users\__USERNAME__'
    return $Text
}

# 비밀로 의심되는 키 이름 패턴
$SecretKeyPattern = '(?i)(TOKEN|KEY|SECRET|PASSWORD|PAT|CREDENTIAL)'
$DetectedSecrets = @()

# ────────────────────────────────────────────────
# 1. Claude Desktop config 백업 (MCP 서버 목록)
# ────────────────────────────────────────────────
$DesktopConfigPath = Join-Path $env:APPDATA 'Claude\claude_desktop_config.json'

if (Test-Path $DesktopConfigPath) {
    Write-Host "[1/7] Claude Desktop config 읽는 중..." -ForegroundColor Yellow
    $raw = Get-Content $DesktopConfigPath -Raw -Encoding UTF8
    $config = $raw | ConvertFrom-Json

    # env 섹션의 비밀값 마스킹
    if ($config.mcpServers) {
        foreach ($serverName in $config.mcpServers.PSObject.Properties.Name) {
            $server = $config.mcpServers.$serverName
            if ($server.env) {
                foreach ($envKey in @($server.env.PSObject.Properties.Name)) {
                    if ($envKey -match $SecretKeyPattern) {
                        $placeholder = "__SECRET_${serverName}_${envKey}__".ToUpper()
                        $DetectedSecrets += [pscustomobject]@{
                            Server      = $serverName
                            Key         = $envKey
                            Placeholder = $placeholder
                        }
                        $server.env.$envKey = $placeholder
                    }
                }
            }
        }
    }

    # JSON 직렬화 후 사용자명도 치환
    $jsonOut = $config | ConvertTo-Json -Depth 100
    $jsonOut = Convert-ToTemplate -Text $jsonOut -UserName $CurrentUser

    $outPath = Join-Path $Snapshot 'claude_desktop_config.template.json'
    if (-not $DryRun) { $jsonOut | Set-Content -Path $outPath -Encoding UTF8 }
    Write-Host "      → claude_desktop_config.template.json ($(@($config.mcpServers.PSObject.Properties).Count)개 MCP 서버)" -ForegroundColor DarkGray
} else {
    Write-Host "[1/7] Claude Desktop config 없음 (건너뜀)" -ForegroundColor DarkYellow
}

# ────────────────────────────────────────────────
# 2. Claude Code 설정 백업 (~/.claude/*)
# ────────────────────────────────────────────────
Write-Host "[2/7] Claude Code 설정 백업 중..." -ForegroundColor Yellow
$ClaudeHome = Join-Path $env:USERPROFILE '.claude'

$ccTargets = @(
    @{ Source = Join-Path $ClaudeHome 'settings.json';      Dest = 'claude-code-settings.json' }
    @{ Source = Join-Path $ClaudeHome 'CLAUDE.md';          Dest = 'CLAUDE.md' }
    @{ Source = Join-Path $env:USERPROFILE '.claude.json';  Dest = 'claude-code-mcp.template.json' }
)
foreach ($t in $ccTargets) {
    if (Test-Path $t.Source) {
        $content = Get-Content $t.Source -Raw -Encoding UTF8
        $content = Convert-ToTemplate -Text $content -UserName $CurrentUser
        $outFile = Join-Path $Snapshot $t.Dest
        if (-not $DryRun) { $content | Set-Content -Path $outFile -Encoding UTF8 }
        Write-Host "      → $($t.Dest)" -ForegroundColor DarkGray
    }
}

# ────────────────────────────────────────────────
# 3. Skills 폴더 백업 (~/.claude/skills/)
# ────────────────────────────────────────────────
$SkillsSrc = Join-Path $ClaudeHome 'skills'
if (Test-Path $SkillsSrc) {
    $SkillsDst = Join-Path $Snapshot 'skills'
    if (-not $DryRun) {
        Copy-Item -Path $SkillsSrc -Destination $SkillsDst -Recurse -Force
    }
    $skillCount = (Get-ChildItem $SkillsSrc -Directory).Count
    Write-Host "[3/7] Skills 폴더 복사 → snapshot/skills/ ($skillCount 개 스킬)" -ForegroundColor Green
} else {
    Write-Host "[3/7] Skills 폴더 없음 (건너뜀)" -ForegroundColor DarkYellow
}

# ────────────────────────────────────────────────
# 3+. Claude Desktop skills (%APPDATA%\Claude\skills)
# ────────────────────────────────────────────────
$DesktopSkillsSrc = Join-Path $env:APPDATA 'Claude\skills'
if (Test-Path $DesktopSkillsSrc) {
    $DesktopSkillsDst = Join-Path $Snapshot 'skills-desktop'
    if (-not $DryRun) { Copy-Item -Path $DesktopSkillsSrc -Destination $DesktopSkillsDst -Recurse -Force }
    $cnt = (Get-ChildItem $DesktopSkillsSrc -Directory).Count
    Write-Host "[3+] Desktop Skills 폴더 복사 → snapshot/skills-desktop/ ($cnt 개)" -ForegroundColor Green
}

# ────────────────────────────────────────────────
# 3++. Claude Code 추가 폴더 (plugins, commands, templates)
# ────────────────────────────────────────────────
foreach ($extra in @('plugins','commands','templates')) {
    $extraSrc = Join-Path $ClaudeHome $extra
    if (Test-Path $extraSrc) {
        $extraDst = Join-Path $Snapshot $extra
        if (-not $DryRun) { Copy-Item -Path $extraSrc -Destination $extraDst -Recurse -Force }
        $cnt = (Get-ChildItem $extraSrc -ErrorAction SilentlyContinue).Count
        Write-Host "[3+] $extra 폴더 복사 → snapshot/$extra/ ($cnt 개)" -ForegroundColor Green
    }
}
# ────────────────────────────────────────────────
# 4. Python 패키지 목록 (pip freeze)
# ────────────────────────────────────────────────
if (-not $SkipPip) {
    Write-Host "[4/7] Python 패키지 목록 추출 중..." -ForegroundColor Yellow
    try {
        $pipList = & pip freeze 2>$null
        if ($pipList) {
            $outFile = Join-Path $Snapshot 'pip-freeze.txt'
            if (-not $DryRun) { $pipList | Set-Content -Path $outFile -Encoding UTF8 }
            Write-Host "      → pip-freeze.txt ($($pipList.Count) 개 패키지)" -ForegroundColor DarkGray
        }
    } catch {
        Write-Host "      pip 명령어 실패 (건너뜀)" -ForegroundColor DarkYellow
    }
} else {
    Write-Host "[4/7] pip 건너뜀 (-SkipPip)" -ForegroundColor DarkGray
}

# ────────────────────────────────────────────────
# 5. npm 글로벌 패키지 목록
# ────────────────────────────────────────────────
if (-not $SkipNpm) {
    Write-Host "[5/7] npm 글로벌 패키지 목록 추출 중..." -ForegroundColor Yellow
    try {
        $npmList = & npm list -g --depth=0 --json 2>$null | ConvertFrom-Json
        if ($npmList.dependencies) {
            $pkgNames = $npmList.dependencies.PSObject.Properties.Name
            $outFile = Join-Path $Snapshot 'npm-globals.txt'
            if (-not $DryRun) { $pkgNames | Set-Content -Path $outFile -Encoding UTF8 }
            Write-Host "      → npm-globals.txt ($($pkgNames.Count) 개 패키지)" -ForegroundColor DarkGray
        }
    } catch {
        Write-Host "      npm 명령어 실패 (건너뜀)" -ForegroundColor DarkYellow
    }
} else {
    Write-Host "[5/7] npm 건너뜀 (-SkipNpm)" -ForegroundColor DarkGray
}

# ────────────────────────────────────────────────
# 6. .env.example 생성 (감지된 비밀 키 목록)
# ────────────────────────────────────────────────
Write-Host "[6/7] .env.example 생성 중..." -ForegroundColor Yellow
$envExample = @()
$envExample += "# ───────────────────────────────────────────────────"
$envExample += "# 이 파일은 자동 생성됨 — 실제 값은 import.ps1 실행 시 입력"
$envExample += "# 절대 .env에 실제 값을 직접 적어 커밋하지 말 것"
$envExample += "# ───────────────────────────────────────────────────"
$envExample += ""
foreach ($s in $DetectedSecrets) {
    $envExample += "# [$($s.Server)] $($s.Key)"
    $envExample += "$($s.Placeholder)="
    $envExample += ""
}
if ($DetectedSecrets.Count -eq 0) {
    $envExample += "# 감지된 비밀 키가 없습니다."
}
$envExamplePath = Join-Path $RepoRoot '.env.example'
if (-not $DryRun) { $envExample | Set-Content -Path $envExamplePath -Encoding UTF8 }
Write-Host "      → .env.example ($($DetectedSecrets.Count) 개 비밀 키 자리표시자)" -ForegroundColor DarkGray

# ────────────────────────────────────────────────
# 7. manifest.json — 메타정보
# ────────────────────────────────────────────────
$manifest = [ordered]@{
    exportedAt   = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    sourceUser   = $CurrentUser
    sourceHost   = $env:COMPUTERNAME
    osVersion    = [System.Environment]::OSVersion.VersionString
    psVersion    = $PSVersionTable.PSVersion.ToString()
    secretsCount = $DetectedSecrets.Count
    secretKeys   = @($DetectedSecrets | ForEach-Object { $_.Placeholder })
}
$manifestPath = Join-Path $Snapshot 'manifest.json'
if (-not $DryRun) {
    $manifest | ConvertTo-Json -Depth 5 | Set-Content -Path $manifestPath -Encoding UTF8
}
Write-Host "[7/7] manifest.json 생성 완료" -ForegroundColor Green

# ────────────────────────────────────────────────
# 마무리
# ────────────────────────────────────────────────
Write-Host ""
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  ✓ Export 완료" -ForegroundColor Green
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "다음 단계:" -ForegroundColor White
Write-Host "  1. git add . && git commit -m '환경 백업 $(Get-Date -Format yyyy-MM-dd)'" -ForegroundColor Gray
Write-Host "  2. git push" -ForegroundColor Gray
Write-Host "  3. 새 PC에서 git clone 후 .\import.ps1 실행" -ForegroundColor Gray
Write-Host ""
if ($DetectedSecrets.Count -gt 0) {
    Write-Host "⚠  $($DetectedSecrets.Count)개의 비밀 키가 자리표시자로 마스킹되었습니다." -ForegroundColor Yellow
    Write-Host "   실제 값은 import.ps1 실행 시 입력 받습니다." -ForegroundColor Yellow
    Write-Host ""
}
if ($DryRun) {
    Write-Host "※ DryRun 모드 — 실제 파일은 생성되지 않았습니다." -ForegroundColor Magenta
}
