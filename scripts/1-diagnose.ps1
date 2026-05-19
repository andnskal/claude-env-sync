# ============================================================
#  1-diagnose.ps1
#  환경 진단 스크립트
#  새 PC의 시스템 상태를 점검합니다.
# ============================================================

param(
    [switch]$SkipPause,
    [string]$OutputFile = "$PSScriptRoot\..\.diagnosis.json"
)

$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

# 헬퍼 로드
. (Join-Path $RepoRoot 'scripts\lib\ui-helpers.ps1')
. (Join-Path $RepoRoot 'scripts\lib\env-validator.ps1')

Write-Title "1단계: 시스템 환경 진단"

Write-Step 1 3 "시스템 정보 수집 중..."
$diagnosis = Diagnose-Environment
Start-Sleep -Milliseconds 500

Write-Step 2 3 "진단 결과 출력 중..."
Report-Diagnosis $diagnosis
Start-Sleep -Milliseconds 500

Write-Step 3 3 "진단 데이터 저장 중..."
$diagnosis | ConvertTo-Json -Depth 5 | Out-File $OutputFile -Encoding UTF8 -Force
Write-Success "진단 결과를 저장했습니다: $OutputFile"

Write-Host ""
Write-Info "다음: 2-build-mapping.ps1을 실행하여 경로 매핑 테이블을 생성합니다."

if (-not $SkipPause) {
    Pause-ForUser "계속하려면 아무 키나 누르세요..."
}
