# ============================================================
#  5-verify.ps1
#  MCP 검증 스크립트
#  모든 MCP 서버가 정상 동작하는지 확인합니다.
# ============================================================

param(
    [string]$ConfigFile = "$env:APPDATA\Claude\claude_desktop_config.json",
    [switch]$SkipPause
)

$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

# 헬퍼 로드
. (Join-Path $RepoRoot 'scripts\lib\ui-helpers.ps1')

Write-Title "5단계: MCP 검증"

Write-Step 1 4 "Claude Desktop config 로드 중..."
if (-not (Test-Path $ConfigFile)) {
    Write-Error "Claude Desktop config를 찾을 수 없습니다: $ConfigFile"
    exit 1
}

$config = Get-Content $ConfigFile -Raw | ConvertFrom-Json
$mcpServers = $config.mcpServers.PSObject.Properties
Write-Success "$(($mcpServers | Measure-Object).Count)개의 MCP 서버를 발견했습니다."
Start-Sleep -Milliseconds 500

Write-Step 2 4 "각 MCP 서버 경로 검증 중..."
$pathIssues = @()

foreach ($svc in $mcpServers) {
    $name = $svc.Name
    $obj = $svc.Value
    
    Write-Info "검증: [$name]"
    
    # command 경로 확인
    $command = $obj.command
    
    if ($command -match '^[A-Z]:\\') {
        # 절대 경로
        if (Test-Path $command) {
            Write-Success "  ✓ Command: $command"
        } else {
            Write-Warning "  ✗ Command not found: $command"
            $pathIssues += @{
                'Service' = $name
                'Type' = 'command'
                'Path' = $command
                'Status' = 'MISSING'
            }
        }
    } else {
        # 상대 경로 또는 npx (검증 skip)
        Write-Info "  ℹ Command: $command (npx/상대경로)"
    }
    
    # args에서 경로 확인
    if ($obj.args) {
        foreach ($arg in $obj.args) {
            if ($arg -match '^[A-Z]:\\' -and $arg -notmatch '^[A-Z]:\\\\$') {
                if (Test-Path $arg) {
                    Write-Success "  ✓ Arg: $arg"
                } else {
                    Write-Warning "  ✗ Arg not found: $arg"
                    $pathIssues += @{
                        'Service' = $name
                        'Type' = 'arg'
                        'Path' = $arg
                        'Status' = 'MISSING'
                    }
                }
            }
        }
    }
}

if ($pathIssues.Count -gt 0) {
    Write-Host ""
    Write-Warning "경로 검증 결과:"
    foreach ($issue in $pathIssues) {
        Write-Host "  - [$($issue['Service'])] $($issue['Type']): $($issue['Path'])"
    }
} else {
    Write-Success "모든 경로가 유효합니다."
}
Start-Sleep -Milliseconds 500

Write-Step 3 4 "필수 도구 확인 중..."
$tools = @{
    'Python' = 'python --version'
    'Node.js' = 'node --version'
    'npm' = 'npm --version'
}

foreach ($tool in $tools.Keys) {
    $cmd = $tools[$tool]
    try {
        $version = Invoke-Expression $cmd 2>&1
        Write-Success "  ✓ $tool: $version"
    } catch {
        Write-Warning "  ✗ $tool: 설치 안 됨"
    }
}
Start-Sleep -Milliseconds 500

Write-Step 4 4 "최종 단계: Claude Desktop 재시작 필요"
Write-Info "Claude Desktop을 완전히 종료한 후 다시 시작하세요."
Write-Info "  1. 시스템 트레이에서 Claude 아이콘을 마우스 우클릭"
Write-Info "  2. '종료' 선택"
Write-Info "  3. Claude Desktop 다시 실행"
Write-Info "  4. 우측 하단 🔌 아이콘으로 MCP 상태 확인 (모두 녹색이어야 함)"

Write-Host ""
Write-Success "검증 단계가 완료되었습니다!"

if ($pathIssues.Count -gt 0) {
    Write-Warning "경로 누락이 발견되었습니다. PREREQUISITES.md를 참고하여 수동으로 설치해주세요."
} else {
    Write-Success "모든 검증이 통과했습니다. Claude Desktop을 재시작하세요!"
}

if (-not $SkipPause) {
    Pause-ForUser "계속하려면 아무 키나 누르세요..."
}
