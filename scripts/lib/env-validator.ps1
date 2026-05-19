# ============================================================
# Environment Validator Functions
# 시스템 환경 진단 및 검증
# ============================================================

function Get-SystemInfo {
    <#
    시스템 기본 정보 반환
    #>
    return @{
        'Username' = $env:USERNAME
        'ComputerName' = $env:COMPUTERNAME
        'OSVersion' = [System.Environment]::OSVersion.VersionString
        'PowerShellVersion' = $PSVersionTable.PSVersion.ToString()
        'ProcessorCount' = [System.Environment]::ProcessorCount
    }
}

function Test-UnicodeUsername {
    <#
    사용자명에 한글/특수문자가 있는지 확인
    #>
    $username = $env:USERNAME
    # ASCII 범위 벗어나면 한글 포함
    return $username -match '[^\x00-\x7F]'
}

function Get-AvailableDrives {
    <#
    사용 가능한 드라이브 목록 반환 (용량 정보 포함)
    #>
    $drives = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Root -match '^[A-Z]:' }
    $result = @()
    
    foreach ($drive in $drives) {
        try {
            $vol = Get-Volume -DriveLetter $drive.Name -ErrorAction SilentlyContinue
            if ($vol) {
                $result += @{
                    'Drive' = "$($drive.Name):"
                    'Label' = $vol.FileSystemLabel
                    'FreeGB' = [math]::Round($vol.SizeRemaining / 1GB, 2)
                    'TotalGB' = [math]::Round($vol.Size / 1GB, 2)
                }
            }
        } catch {
            # 드라이브 접근 불가, 스킵
        }
    }
    
    return $result
}

function Test-ClaudeDesktopInstalled {
    <#
    Claude Desktop이 설치되어 있는지 확인
    #>
    $appPath = "$env:APPDATA\Claude\claude_desktop_config.json"
    return (Test-Path $appPath)
}

function Test-ClaudeCodeInstalled {
    <#
    Claude Code가 설치되어 있는지 확인
    #>
    $codeHome = Join-Path $env:USERPROFILE '.claude'
    return (Test-Path $codeHome -PathType Container)
}

function Test-PythonInstalled {
    <#
    Python이 설치되어 있는지 확인하고 버전 반환
    #>
    $pythonCmd = Get-Command python -ErrorAction SilentlyContinue
    if ($pythonCmd) {
        $version = & python --version 2>&1
        return @{ 'Installed' = $true; 'Version' = $version; 'Path' = $pythonCmd.Source }
    }
    return @{ 'Installed' = $false; 'Version' = ''; 'Path' = '' }
}

function Test-NodeInstalled {
    <#
    Node.js가 설치되어 있는지 확인하고 버전 반환
    #>
    $nodeCmd = Get-Command node -ErrorAction SilentlyContinue
    if ($nodeCmd) {
        $version = & node --version 2>&1
        return @{ 'Installed' = $true; 'Version' = $version; 'Path' = $nodeCmd.Source }
    }
    return @{ 'Installed' = $false; 'Version' = ''; 'Path' = '' }
}

function Test-NpmInstalled {
    <#
    npm이 설치되어 있는지 확인하고 버전 반환
    #>
    $npmCmd = Get-Command npm -ErrorAction SilentlyContinue
    if ($npmCmd) {
        $version = & npm --version 2>&1
        return @{ 'Installed' = $true; 'Version' = $version; 'Path' = $npmCmd.Source }
    }
    return @{ 'Installed' = $false; 'Version' = ''; 'Path' = '' }
}

function Test-WingetInstalled {
    <#
    winget이 설치되어 있는지 확인
    #>
    $wingetCmd = Get-Command winget -ErrorAction SilentlyContinue
    return ($null -ne $wingetCmd)
}

function Get-PathWithSpecialChars {
    <#
    현재 경로에 특수문자(한글, 공백, @, # 등)가 있는지 확인
    #>
    $path = Get-Location
    return @{
        'Path' = $path.Path
        'HasSpaces' = $path.Path -match '\s'
        'HasUnicode' = $path.Path -match '[^\x00-\x7F]'
        'HasSpecialChars' = $path.Path -match '[@#$%^&()]'
    }
}

function Diagnose-Environment {
    <#
    시스템 환경을 종합 진단하고 결과를 반환합니다.
    #>
    $diagnosis = @{
        'SystemInfo' = Get-SystemInfo
        'HasUnicodeUsername' = Test-UnicodeUsername
        'AvailableDrives' = Get-AvailableDrives
        'ClaudeDesktop' = Test-ClaudeDesktopInstalled
        'ClaudeCode' = Test-ClaudeCodeInstalled
        'Python' = Test-PythonInstalled
        'Node' = Test-NodeInstalled
        'Npm' = Test-NpmInstalled
        'Winget' = Test-WingetInstalled
        'PathIssues' = Get-PathWithSpecialChars
    }
    
    return $diagnosis
}

function Report-Diagnosis {
    <#
    진단 결과를 읽기 좋게 출력합니다.
    #>
    param([hashtable]$Diagnosis)
    
    Write-Host "=== 시스템 정보 ===" -ForegroundColor Cyan
    foreach ($key in $Diagnosis['SystemInfo'].Keys) {
        Write-Host "  $key : $($Diagnosis['SystemInfo'][$key])"
    }
    
    Write-Host ""
    Write-Host "=== 사용자명 ===" -ForegroundColor Cyan
    Write-Host "  사용자: $($Diagnosis['SystemInfo']['Username'])"
    if ($Diagnosis['HasUnicodeUsername']) {
        Write-Host "  ⚠ 한글/특수문자 포함!" -ForegroundColor Yellow
    } else {
        Write-Host "  ✓ ASCII 문자만 사용" -ForegroundColor Green
    }
    
    Write-Host ""
    Write-Host "=== 사용 가능한 드라이브 ===" -ForegroundColor Cyan
    foreach ($drive in $Diagnosis['AvailableDrives']) {
        $free = $drive['FreeGB']
        $total = $drive['TotalGB']
        $pct = [math]::Round(($free / $total) * 100)
        Write-Host "  $($drive['Drive']) ($($drive['Label'])) : $free GB / $total GB (여유: $pct%)"
    }
    
    Write-Host ""
    Write-Host "=== 설치 상태 ===" -ForegroundColor Cyan
    Write-Host "  Claude Desktop : $(if ($Diagnosis['ClaudeDesktop']) { '✓ 설치됨' } else { '✗ 미설치' })"
    Write-Host "  Claude Code : $(if ($Diagnosis['ClaudeCode']) { '✓ 설치됨' } else { '✗ 미설치' })"
    
    $python = $Diagnosis['Python']
    Write-Host "  Python : $(if ($python['Installed']) { "✓ $($python['Version'])" } else { '✗ 미설치' })"
    
    $node = $Diagnosis['Node']
    Write-Host "  Node.js : $(if ($node['Installed']) { "✓ $($node['Version'])" } else { '✗ 미설치' })"
    
    $npm = $Diagnosis['Npm']
    Write-Host "  npm : $(if ($npm['Installed']) { "✓ $($npm['Version'])" } else { '✗ 미설치' })"
    
    Write-Host "  winget : $(if ($Diagnosis['Winget']) { '✓ 설치됨' } else { '✗ 미설치' })"
    
    Write-Host ""
    Write-Host "=== 경로 정보 ===" -ForegroundColor Cyan
    $pathIssues = $Diagnosis['PathIssues']
    Write-Host "  현재 경로: $($pathIssues['Path'])"
    if ($pathIssues['HasSpaces']) {
        Write-Host "  ⚠ 경로에 공백 포함" -ForegroundColor Yellow
    }
    if ($pathIssues['HasUnicode']) {
        Write-Host "  ⚠ 경로에 한글 포함" -ForegroundColor Yellow
    }
    if ($pathIssues['HasSpecialChars']) {
        Write-Host "  ⚠ 경로에 특수문자 포함" -ForegroundColor Yellow
    }
}

function Get-DiagnosisJson {
    <#
    진단 결과를 JSON으로 변환합니다 (저장/비교용).
    #>
    param([hashtable]$Diagnosis)
    return $Diagnosis | ConvertTo-Json -Depth 3
}
