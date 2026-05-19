# ============================================================
# Git Helper Functions
# Git 설치 확인, 경로 탐색, 자동 설치
# ============================================================

function Get-GitPath {
    <#
    시스템에서 git 실행 파일의 경로를 찾아 반환합니다.
    없으면 $null 반환.
    #>
    $candidates = @(
        'C:\Program Files\Git\cmd\git.exe',
        'C:\Program Files (x86)\Git\cmd\git.exe',
        'C:\Tools\Git\cmd\git.exe',
        "$env:ProgramFiles\Git\cmd\git.exe"
    )
    
    foreach ($path in $candidates) {
        if (Test-Path $path) { return $path }
    }
    
    # 환경 변수 PATH에서 검색
    $pathDirs = $env:Path -split ';'
    foreach ($dir in $pathDirs) {
        $gitPath = Join-Path $dir 'git.exe'
        if (Test-Path $gitPath) { return $gitPath }
    }
    
    return $null
}

function Test-GitInstalled {
    <# git이 설치되어 있는지 확인 #>
    $gitPath = Get-GitPath
    return ($null -ne $gitPath)
}

function Install-Git {
    <#
    winget을 사용하여 Git을 자동 설치합니다.
    #>
    Write-Info "Git이 설치되어 있지 않습니다. winget을 사용하여 설치하겠습니다..."
    
    try {
        winget install --id Git.Git --silent --accept-source-agreements --accept-package-agreements
        Start-Sleep -Seconds 3
        
        if (Test-GitInstalled) {
            Write-Success "Git이 설치되었습니다."
            return $true
        } else {
            Write-Error "Git 설치 후에도 경로를 찾을 수 없습니다."
            return $false
        }
    } catch {
        Write-Error "Git 설치 중 오류 발생: $_"
        return $false
    }
}

function Invoke-Git {
    <#
    git 명령을 실행하고 결과를 반환합니다.
    #>
    param(
        [string]$Arguments,
        [string]$WorkingDirectory = (Get-Location),
        [switch]$NoError
    )
    
    $gitPath = Get-GitPath
    if (-not $gitPath) {
        throw "Git을 찾을 수 없습니다."
    }
    
    $originalLocation = Get-Location
    try {
        Set-Location $WorkingDirectory
        $output = & $gitPath $Arguments 2>&1
        if ($LASTEXITCODE -ne 0 -and -not $NoError) {
            throw "Git 명령 실패: git $Arguments`n$output"
        }
        return $output
    } finally {
        Set-Location $originalLocation
    }
}

function Test-GitRepo {
    <# 현재 디렉토리가 git repo인지 확인 #>
    return (Test-Path '.git' -PathType Container)
}

function Get-GitCurrentBranch {
    <# 현재 git 브랜치 이름 반환 #>
    $branch = Invoke-Git 'branch --show-current' -NoError
    return ($branch -join '').Trim()
}

function Ensure-GitClone {
    <#
    repo를 clone합니다. 이미 있으면 skip합니다.
    #>
    param(
        [string]$RepoUrl,
        [string]$DestinationPath
    )
    
    if (Test-Path $DestinationPath) {
        Write-Info "이미 clone되어 있습니다: $DestinationPath"
        return $true
    }
    
    $parentDir = Split-Path $DestinationPath -Parent
    if (-not (Test-Path $parentDir)) {
        New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
    }
    
    Write-Info "Cloning $RepoUrl..."
    Invoke-Git "clone $RepoUrl `"$DestinationPath`"" -WorkingDirectory $parentDir
    return (Test-Path $DestinationPath)
}

function Ensure-GitConfigLocal {
    <#
    git config user.name/user.email을 로컬로 설정합니다 (global이 아님).
    GitHub noreply 이메일 형식 사용.
    #>
    param([string]$WorkingDirectory = (Get-Location))
    
    $name = Invoke-Git 'config user.name' -WorkingDirectory $WorkingDirectory -NoError | ForEach-Object Trim
    if (-not $name) {
        $ghUser = (Invoke-WebRequest 'https://api.github.com/user' -UseBasicParsing -ErrorAction SilentlyContinue | ConvertFrom-Json).login
        if ($ghUser) {
            Invoke-Git "config --local user.name $ghUser" -WorkingDirectory $WorkingDirectory
            $ghId = (Invoke-WebRequest 'https://api.github.com/user' -UseBasicParsing -ErrorAction SilentlyContinue | ConvertFrom-Json).id
            $noreply = "$ghId+$ghUser@users.noreply.github.com"
            Invoke-Git "config --local user.email $noreply" -WorkingDirectory $WorkingDirectory
        }
    }
}
