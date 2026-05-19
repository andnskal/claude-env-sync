# ============================================================
#  2-build-mapping.ps1
#  경로 매핑 테이블 생성 스크립트
#  원본 경로 → 새 PC 경로 변환 규칙을 만듭니다.
# ============================================================

param(
    [string]$SourceUsername = 'junhyeok',
    [string]$SourceGooglePath = 'D:\claude\mcp-google-sheets-extended',
    [string]$SourcePyhubPath = 'C:\pyhub.mcptools',
    [switch]$SkipPause,
    [string]$OutputFile = "$PSScriptRoot\..\.mapping.json"
)

$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

# 헬퍼 로드
. (Join-Path $RepoRoot 'scripts\lib\ui-helpers.ps1')
. (Join-Path $RepoRoot 'scripts\lib\path-helpers.ps1')

Write-Title "2단계: 경로 매핑 테이블 생성"

Write-Step 1 4 "매핑 규칙 생성 중..."
$mapping = Build-PathMapping -SourceUsername $SourceUsername `
                              -SourceGooglePath $SourceGooglePath `
                              -SourcePyhubPath $SourcePyhubPath
Start-Sleep -Milliseconds 500

Write-Step 2 4 "매핑 결과 표시 중..."
Write-Host ""
Write-Host "매핑 규칙:" -ForegroundColor Green
foreach ($key in ($mapping.Keys | Sort-Object)) {
    $value = $mapping[$key]
    Write-Host "  $key"
    Write-Host "    → $value" -ForegroundColor Cyan
}
Start-Sleep -Milliseconds 500

Write-Step 3 4 "매핑 검증 중..."
$issues = Validate-PathMapping $mapping
if ($issues.Count -gt 0) {
    Write-Warning "경로 매핑 검증 결과:"
    foreach ($issue in $issues) {
        Write-Host "  ⚠ $issue"
    }
} else {
    Write-Success "모든 매핑이 유효합니다."
}
Start-Sleep -Milliseconds 500

Write-Step 4 4 "매핑 데이터 저장 중..."
$mapping | ConvertTo-Json | Out-File $OutputFile -Encoding UTF8 -Force
Write-Success "매핑 테이블을 저장했습니다: $OutputFile"

Write-Host ""
if (Ask-YesNo "이 매핑으로 진행하시겠습니까?") {
    Write-Success "진행하겠습니다."
    Write-Info "다음: 3-apply-mapping.ps1을 실행하여 매핑을 적용합니다."
} else {
    Write-Warning "매핑을 수정하고 다시 실행해주세요."
    exit 1
}

if (-not $SkipPause) {
    Pause-ForUser "계속하려면 아무 키나 누르세요..."
}
