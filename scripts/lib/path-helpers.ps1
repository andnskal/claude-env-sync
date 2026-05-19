# ============================================================
# Path Helper Functions
# 드라이브 감지, 경로 매핑, 한글 처리
# ============================================================

function Get-LargestDrive {
    <#
    사용 가능한 드라이브 중 가장 큰 공간이 있는 드라이브를 반환합니다.
    #>
    $drives = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Root -match '^[A-Z]:' }
    
    $largest = $null
    $maxFree = 0
    
    foreach ($drive in $drives) {
        try {
            $vol = Get-Volume -DriveLetter $drive.Name -ErrorAction SilentlyContinue
            if ($vol -and $vol.SizeRemaining -gt $maxFree) {
                $largest = $drive.Name
                $maxFree = $vol.SizeRemaining
            }
        } catch {
            # 드라이브 접근 불가, 스킵
        }
    }
    
    return $largest
}

function Test-DriveExists {
    <# 특정 드라이브가 존재하는지 확인 #>
    param([string]$Drive)
    $Drive = $Drive -replace ':\\$', ''
    return (Test-Path "$Drive`:\" -PathType Container)
}

function Find-AlternativeDrive {
    <#
    D:\와 같은 경로가 있는 드라이브를 찾습니다.
    없으면 가장 큰 드라이브를 반환합니다.
    #>
    param([string]$PreferredPath)
    
    # 첫 번째 문자가 드라이브 레터인지 확인
    if ($PreferredPath -match '^([A-Z]):') {
        $driveLetter = $matches[1]
        if (Test-DriveExists $driveLetter) {
            return $driveLetter
        }
    }
    
    # 선호 드라이브가 없으면 가장 큰 드라이브 반환
    $largest = Get-LargestDrive
    return if ($largest) { $largest } else { 'C' }
}

function Build-PathMapping {
    <#
    원본 환경과 새 환경의 경로 매핑 테이블을 생성합니다.
    
    출력:
    @{
        'junhyeok' = 'newuser'
        'C:\Users\junhyeok' = 'C:\Users\newuser'
        'D:' = 'C'  (D가 없으면)
        ...
    }
    #>
    param(
        [string]$SourceUsername = 'junhyeok',  # 원본 PC의 사용자명
        [string]$SourceGooglePath = 'D:\claude\mcp-google-sheets-extended',
        [string]$SourcePyhubPath = 'C:\pyhub.mcptools'
    )
    
    $mapping = @{}
    $currentUser = $env:USERNAME
    
    # 1. 사용자명 매핑
    $mapping['__USERNAME__'] = $currentUser
    $mapping[$SourceUsername] = $currentUser
    
    # 2. 사용자 경로 매핑
    $sourcePath = "C:\Users\$SourceUsername"
    $currentPath = "C:\Users\$currentUser"
    $mapping[$sourcePath] = $currentPath
    $mapping['__USERPROFILE__'] = $currentPath
    
    # 3. 드라이브 매핑 (google-sheets의 경로에서 드라이브 감지)
    if ($SourceGooglePath -match '^([A-Z]):') {
        $sourceDrive = $matches[1]
        
        if (Test-DriveExists $sourceDrive) {
            # 원본 드라이브가 있으면 그대로
            $targetDrive = $sourceDrive
            $mapping["$sourceDrive`:\"] = "$targetDrive`:\claude-data\"
            $mapping["$sourceDrive`:\\"] = "$targetDrive`:\claude-data\"
        } else {
            # 없으면 가장 큰 드라이브 사용
            $targetDrive = Get-LargestDrive
            if (-not $targetDrive) { $targetDrive = 'C' }
            $mapping["$sourceDrive`:\"] = "$targetDrive`:\ClaudeData\"
            $mapping["$sourceDrive`:\\"] = "$targetDrive`:\ClaudeData\"
        }
    }
    
    # 4. Python 버전 매핑 (sqlite 실행 파일)
    # 원본: C:\Users\junhyeok\AppData\Local\Programs\Python\Python314\Scripts\
    # 새PC: 실제 설치된 Python 버전으로 자동 감지
    $pythonExe = Get-Command python -ErrorAction SilentlyContinue
    if ($pythonExe) {
        $pythonPath = Split-Path $pythonExe.Source -Parent | Split-Path -Parent | Split-Path -Parent
        # 원본 패턴과 매핑
        $mapping['Python314'] = (Get-Item $pythonPath).Name -replace 'Python', 'Python'
        $mapping["C:\Users\$SourceUsername\AppData\Local\Programs\Python\Python314"] = (Join-Path $pythonPath 'Scripts')
    }
    
    # 5. 외부 경로 매핑 (pyhub, google-sheets-extended)
    $mapping['C:\pyhub.mcptools'] = 'C:\pyhub.mcptools'  # 고정 위치
    $mapping['D:\claude\mcp-google-sheets-extended'] = "$((Find-AlternativeDrive $SourceGooglePath)`):\ClaudeData\mcp-google-sheets-extended"
    
    return $mapping
}

function Apply-PathMapping {
    <#
    JSON 문자열에 경로 매핑을 적용합니다.
    #>
    param(
        [string]$JsonString,
        [hashtable]$Mapping
    )
    
    $result = $JsonString
    
    # 매핑 순서가 중요합니다: 긴 경로부터 짧은 경로로
    $sortedKeys = $Mapping.Keys | Sort-Object -Property { $_.Length } -Descending
    
    foreach ($key in $sortedKeys) {
        $replacement = $Mapping[$key]
        
        # JSON 이스케이프 처리 (백슬래시 2배)
        $keyEscaped = $key -replace '\\', '\\\\'
        $replacementEscaped = $replacement -replace '\\', '\\\\'
        
        # 대소문자 구분 없이 치환 (Windows 경로는 case-insensitive)
        $pattern = [regex]::Escape($keyEscaped)
        $result = [regex]::Replace($result, $pattern, $replacementEscaped, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    }
    
    return $result
}

function Get-PathsInJson {
    <#
    JSON 문자열에서 모든 경로를 추출합니다 (디버깅용).
    #>
    param([string]$JsonString)
    
    # 간단한 패턴: 드라이브 문자로 시작하는 경로
    $pattern = '[A-Z]:\\[^"]*'
    $matches = [regex]::Matches($JsonString, $pattern)
    return $matches.Value | Sort-Object -Unique
}

function Validate-PathMapping {
    <#
    경로 매핑이 실제로 존재하는지 검증합니다.
    #>
    param([hashtable]$Mapping)
    
    $issues = @()
    
    foreach ($key in $Mapping.Keys) {
        $target = $Mapping[$key]
        
        # C:\ 형태의 드라이브는 skip (존재 확인 불필요)
        if ($target -match '^[A-Z]:\\$') { continue }
        
        # 폴더는 아직 없을 수 있으니 부모 폴더만 확인
        $parent = Split-Path $target -Parent
        if ($parent -and -not (Test-Path $parent -PathType Container)) {
            $issues += "대상 경로의 부모 폴더가 없음: $target (부모: $parent)"
        }
    }
    
    return $issues
}
