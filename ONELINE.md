# 🚀 한 줄로 설치하기

이 페이지는 새로운 PC에서 Claude 환경을 한 줄 명령으로 복제하는 방법을 보여줍니다.

## 📋 요구사항

- Windows 10/11
- PowerShell 5.1 이상 (기본 설치됨)
- 인터넷 연결
- GitHub 계정 (repo 접근 권한 필요)

## ⚡ 한 줄 명령 (권장)

**새 PC의 PowerShell에 다음을 붙여넣으면 자동으로 모든 단계가 진행됩니다:**

```powershell
iwr https://raw.githubusercontent.com/andnskal/claude-env-sync/main/scripts/install.ps1 -OutFile $env:TEMP\inst.ps1; powershell -ExecutionPolicy Bypass -File $env:TEMP\inst.ps1
```

**또는 git이 이미 설치되어 있다면:**

```powershell
git clone https://github.com/andnskal/claude-env-sync C:\dev\claude-env-sync; cd C:\dev\claude-env-sync; powershell -ExecutionPolicy Bypass -File .\scripts\install.ps1
```

## 📖 자동 진행 단계

이 명령을 실행하면 다음 단계가 자동으로 진행됩니다:

| 단계 | 설명 | 자동 | 사용자 입력 |
|---|---|---|---|
| 1 | Git 설치 확인 (없으면 자동 설치) | ✅ | — |
| 2 | GitHub 로그인 | ✅ | 8자리 코드 입력 (브라우저) |
| 3 | Repo clone | ✅ | — |
| 4 | **시스템 환경 진단** | ✅ | — |
| 5 | **경로 매핑 테이블 생성** | ✅ | 매핑 확인 (Y/N) |
| 6 | **경로 매핑 적용** | ✅ | — |
| 7 | **외부 의존성 설치** (pyhub, server.py) | ✅ | — |
| 8 | **MCP 검증** | ✅ | — |
| 9 | Claude Desktop 재시작 안내 | — | ✅ 수동 재시작 |

## 🎯 각 단계 설명

### Step 1: 시스템 환경 진단 (자동)

```
✓ 사용자명, 컴퓨터명, OS 버전 감지
✓ 사용 가능한 드라이브 (용량 포함) 감지
✓ Python, Node.js, npm, Git 설치 상태 확인
✓ 한글/특수문자 경로 감지
```

### Step 2: 경로 매핑 테이블 생성 (자동)

원본 PC 환경 → 새 PC 환경으로 자동 변환:

```
원본 경로                           → 새 PC 경로
─────────────────────────────────────────────────
C:\Users\junhyeok\                 → C:\Users\<현재 사용자명>\
D:\claude\...                      → D:\... (또는 C:\ClaudeData\)
C:\pyhub.mcptools\                 → C:\pyhub.mcptools\ (고정)
```

**D 드라이브가 없는 경우:**
- 자동으로 가장 큰 드라이브 선택 (예: C:\ClaudeData\)
- 사용자에게 미리보기 표시 후 진행

### Step 3: 경로 매핑 적용 (자동)

```
✓ claude_desktop_config.json 변환
✓ claude-code-settings.json 변환
✓ 모든 config 파일에 경로 자동 치환
```

### Step 4: 외부 의존성 설치 (자동)

```
✓ pyhub.mcptools 다운로드 → C:\pyhub.mcptools\ 설치
✓ google-sheets MCP 압축 해제
✓ npm 글로벌 패키지 설치
  - @modelcontextprotocol/server-sequential-thinking
  - @modelcontextprotocol/server-filesystem
  - mcp-server-sqlite
```

### Step 5: MCP 검증 (자동)

```
✓ 모든 경로 유효성 확인
✓ 필수 도구 (Python, Node.js, npm) 확인
✓ Claude Desktop config 검증
```

## 🔧 고급 사용법

### 특정 단계만 실행

```powershell
# 1단계만 실행 (진단)
powershell -ExecutionPolicy Bypass -File .\scripts\install.ps1 -Diagnose

# 2단계만 실행 (매핑 생성)
powershell -ExecutionPolicy Bypass -File .\scripts\install.ps1 -BuildMapping

# 3단계부터 5단계까지
powershell -ExecutionPolicy Bypass -File .\scripts\install.ps1 -ApplyMapping -InstallExternals -Verify
```

### Dry Run (실제 적용 안 함, 미리보기만)

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\3-apply-mapping.ps1 -DryRun
```

## ⚠️ 주의사항

### Google Sheets 서비스 계정

**압축된 `mcp-google-sheets-extended.zip` 안에는 서비스 계정 JSON이 포함되어 있지 않습니다** (보안상 이유).

새 PC에서는 **본인 Google 계정으로 새로운 서비스 계정을 발급받아야 합니다.**

[PREREQUISITES.md](./PREREQUISITES.md)의 "3.5 google-sheets" 섹션을 참고하세요.

### 한글 사용자명

사용자명에 한글이 있으면 자동으로 감지되어 특별히 처리됩니다. 추가 작업 필요 없습니다.

### D 드라이브가 없는 경우

자동으로 가장 큰 드라이브에 `\ClaudeData\` 폴더를 만들어 대신 사용합니다.
사용자에게 미리 확인하는 단계가 있습니다.

## 🐛 문제 해결

### "git을 찾을 수 없습니다"

```powershell
# winget으로 git 설치
winget install --id Git.Git

# PowerShell 재시작 후 다시 시도
```

### "GitHub 로그인 실패"

```powershell
# GitHub CLI 수동 로그인
gh auth login --hostname github.com --git-protocol https --web
```

### MCP 중 일부가 빨강색으로 표시됨

1. Claude Desktop을 **완전히 종료** (트레이에서 우클릭 → 종료)
2. Claude Desktop 다시 실행
3. 다시 🔌 아이콘으로 확인

여전히 빨강색이면 각 MCP의 로그를 확인하세요:
```powershell
# 로그 폴더
$env:USERPROFILE\.claude\debug
```

## 📞 추가 도움

자세한 설정 정보: [PREREQUISITES.md](./PREREQUISITES.md)  
문제 해결: [GitHub Issues](https://github.com/andnskal/claude-env-sync/issues)

---

**준비 완료? 위의 한 줄 명령을 복사해서 PowerShell에 붙여넣으세요!** 🚀
