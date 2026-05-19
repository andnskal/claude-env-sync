# ============================================================
#  3-apply-mapping.ps1
#  경로 매핑 적용 스크립트
#  snapshot의 config 파일들을 새 PC 환경에 맞게 변환합니다.
# ============================================================

param(
    [string]$MappingFile = "$PSScriptRoot\..\.mapping.json",
    [string]$SnapshotPath = "$PSScriptRoot\..\snapshot",
    [switch]$DryRun,
    [switch]$SkipPause
)

$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

# 헬퍼 로드
. (Join-Path $RepoRoot 'scripts\lib\ui-helpers.ps1')
. (Join-Path $RepoRoot 'scripts\lib\path-helpers.ps1')

Write-Title "3단계: 경로 매핑 적용"

if ($DryRun) {
    Write-Warning "DRY RUN 모드: 실제 파일은 변경하지 않습니다."
}

Write-Step 1 5 "매핑 테이블 로드 중..."
if (-not (Test-Path $MappingFile)) {
    Write-Error "매핑 파일을 찾을 수 없습니다: $MappingFile"
    exit 1
}
$mapping = Get-Content $MappingFile -Raw | ConvertFrom-Json -AsHashtable
Write-Success "매핑 테이블 로드 완료: $(($mapping.Keys).Count)개 항목"
Start-Sleep -Milliseconds 500

Write-Step 2 5 "snapshot 파일 스캔 중..."
$jsonFiles = @(
    "$SnapshotPath\claude_desktop_config.template.json",
    "$SnapshotPath\claude-code-settings.json",
    "$SnapshotPath\claude-code-mcp.template.json"
)
$foundCount = 0
foreach ($file in $jsonFiles) {
    if (Test-Path $file) {
        $foundCount++
    }
}
Write-Success "처리 대상 파일: $foundCount개"
Start-Sleep -Milliseconds 500

Write-Step 3 5 "설정 파일 변환 중..."
$processedCount = 0
foreach ($file in $jsonFiles) {
    if (-not (Test-Path $file)) { continue }
    
    $relativePath = $file.Substring($SnapshotPath.Length + 1)
    Write-Info "변환: $relativePath"
    
    $content = Get-Content $file -Raw -Encoding UTF8
    $transformed = Apply-PathMapping -JsonString $content -Mapping $mapping
    
    if (-not $DryRun) {
        # 백업 생성
        $backupFile = "$file.backup"
        if (-not (Test-Path $backupFile)) {
            Copy-Item -Path $file -Destination $backupFile -Force
            Write-Info "  백업: $backupFile"
        }
        
        # 변환된 내용 저장
        Set-Content -Path $file -Value $transformed -Encoding UTF8 -Force
        Write-Success "  완료: $relativePath"
    } else {
        Write-Info "  [DRY RUN] 실제 파일은 변경하지 않습니다."
    }
    
    $processedCount++
}
Write-Success "파일 변환 완료: $processedCount개"
Start-Sleep -Milliseconds 500

Write-Step 4 5 "Claude Desktop config 생성 중..."
$templateFile = "$SnapshotPath\claude_desktop_config.template.json"
$configFile = "$env:APPDATA\Claude\claude_desktop_config.json"

if (Test-Path $templateFile) {
    $templateContent = Get-Content $templateFile -Raw -Encoding UTF8
    
    if (-not $DryRun) {
        # 기존 config 백업
        if (Test-Path $configFile) {
            $backupDir = "$env:APPDATA\Claude\backups\$(Get-Date -Format 'yyyyMMdd-HHmmss')"
            New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
            Copy-Item -Path $configFile -Destination "$backupDir\claude_desktop_config.backup" -Force
            Write-Info "기존 config 백업: $backupDir"
        }
        
        # 새 config 저장
        Set-Content -Path $configFile -Value $templateContent -Encoding UTF8 -Force
        Write-Success "Claude Desktop config 생성 완료"
    } else {
        Write-Info "[DRY RUN] 실제로는 다음 파일을 생성합니다:"
        Write-Host "  $configFile"
    }
} else {
    Write-Warning "template 파일을 찾을 수 없습니다: $templateFile"
}
Start-Sleep -Milliseconds 500

Write-Step 5 5 "Claude Code 설정 복사 중..."
$ccSettingsFile = "$SnapshotPath\claude-code-settings.json"
$ccSettingsTarget = "$env:USERPROFILE\.claude\settings.json"

if (Test-Path $ccSettingsFile) {
    if (-not $DryRun) {
        $targetDir = Split-Path $ccSettingsTarget -Parent
        if (-not (Test-Path $targetDir)) {
            New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
        }
        Copy-Item -Path $ccSettingsFile -Destination $ccSettingsTarget -Force
        Write-Success "Claude Code settings 설정 완료"
    } else {
        Write-Info "[DRY RUN] 실제로는 다음 파일을 복사합니다:"
        Write-Host "  $ccSettingsFile → $ccSettingsTarget"
    }
}

Write-Host ""
if ($DryRun) {
    Write-Warning "DRY RUN이 완료되었습니다. 실제 적용하려면 -DryRun 없이 다시 실행하세요."
    exit 0
}

Write-Success "경로 매핑 적용이 완료되었습니다."
Write-Info "다음: 4-install-externals.ps1을 실행하여 외부 의존성을 설치합니다."

if (-not $SkipPause) {
    Pause-ForUser "계속하려면 아무 키나 누르세요..."
}
