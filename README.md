# Claude 환경 동기화

집 PC ↔ 다른 PC 간에 **Claude Desktop + Claude Code의 MCP 설정, 스킬, 패키지**를 GitHub private repo로 동기화합니다.

- ✅ 집 PC 첫 셋업: **`init.bat` 더블클릭 한 번**
- ✅ 다른 PC 첫 셋업: **PowerShell에 한 줄 붙여넣기**
- ✅ 평소 사용: **`push.bat` / `pull.bat` 더블클릭**

사용자가 PowerShell 명령어를 직접 칠 일은 거의 없습니다.

---

## 🚀 처음 시작하기

### 📍 집 PC (소스) — 단 3단계

**(1) 받은 8개 파일을 한 폴더에 모두 넣기**
- 폴더 위치는 어디든 OK (예: `다운로드\claude-env-sync-init\`)
- 8개 파일:
  ```
  init.bat        bootstrap.ps1
  init.ps1        export.ps1
  push.bat        import.ps1
  pull.bat        README.md  + .gitignore
  ```

**(2) `init.bat` 더블클릭**

자동으로 진행되는 일:
| 단계 | 내용 | 사용자 동작 |
|---|---|---|
| 1 | winget으로 Git, GitHub CLI 자동 설치 | 없음 |
| 2 | GitHub 로그인 (브라우저 열림, 8자리 코드 입력) | **브라우저에서 코드 입력 1회** |
| 3 | private repo `claude-env-sync` 자동 생성 | 없음 |
| 4 | `C:\dev\claude-env-sync` 로 자동 clone | 없음 |
| 5 | 스크립트 파일들 자동 복사 | 없음 |
| 6 | 환경 백업 자동 실행 (export.ps1) | 없음 |
| 7 | GitHub로 자동 push | 없음 |

**(3) 끝!** 

스크립트가 마지막에 다른 PC용 한 줄 명령을 **클립보드에 자동 복사**해줍니다. 회사 PC가서 그냥 붙여넣기만 하면 돼요.

---

### 💻 다른 PC (대상) — PowerShell 한 줄

집 PC에서 init.bat 실행 후, 마지막에 보여준 명령을 다른 PC PowerShell에 붙여넣기:

```powershell
irm https://raw.githubusercontent.com/<본인계정>/claude-env-sync/main/bootstrap.ps1 | iex
```

자동 진행:
1. Git, GitHub CLI 자동 설치
2. GitHub 로그인 (한 번만)
3. repo clone
4. Python, Node.js, uv 자동 설치
5. **API 키 입력** (화면에 안 보이게)
6. 모든 설정·스킬·패키지 복원

---

## 🔄 평소 사용

| 상황 | 어떻게 | 사용 파일 |
|---|---|---|
| 이 PC에서 MCP/스킬 바꿨음 → 다른 PC에 전달 | 더블클릭 | **`push.bat`** |
| 다른 PC에서 바꾼 거 받아옴 | 더블클릭 | **`pull.bat`** |

> 💡 `push.bat` / `pull.bat`을 **바탕화면 바로가기**로 만들어두면 더 편합니다.

---

## ⚠️ 첫 셋업에서 사용자가 직접 하는 일

자동화 불가능한 두 가지만 직접 해주시면 됩니다:

1. **GitHub 로그인** — 브라우저에서 8자리 코드 한 번 입력  
   (`gh auth login`이 자동으로 처리. 한 번 로그인하면 그 PC에서는 영구 캐시)
2. **API 키 입력** — 다른 PC에서 `bootstrap.ps1` 실행 시 1회  
   (감지된 키마다 화면에 표시 안 되게 입력)

---

## 📦 동기화되는 항목

| 항목 | 위치 |
|---|---|
| Claude Desktop MCP 설정 | `%APPDATA%\Claude\claude_desktop_config.json` |
| Claude Code 설정 | `~/.claude/settings.json`, `.claude.json` |
| 글로벌 CLAUDE.md | `~/.claude/CLAUDE.md` |
| Skills 폴더 전체 | `~/.claude/skills/` |
| Python 패키지 (`pip freeze`) | 새 PC에서 자동 재설치 |
| npm 글로벌 패키지 | 새 PC에서 자동 재설치 |

---

## 🔐 보안

- API 키·토큰은 **export 시점에 자동 마스킹** → `__SECRET_*__` 자리표시자만 git에 올라감
- 실제 키는 **import 시 화면에 안 보이게 직접 입력** → 로컬 `.env`에만 저장
- `.gitignore`가 `.env`, `backup/`, 실제 토큰 박힌 config를 모두 차단

push 전에 한 번 확인하고 싶으면:
```powershell
git diff --cached
```

---

## 🩹 트러블슈팅

**❓ init.bat 실행 시 "스크립트 실행이 차단되었습니다"**
- init.bat은 `-ExecutionPolicy Bypass`로 PowerShell을 호출하므로 보통 문제 없음
- 그래도 막히면: PowerShell 관리자 모드에서
  ```powershell
  Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
  ```

**❓ winget이 없다고 함**
- Microsoft Store → "App Installer" 검색 후 설치 → PowerShell 재시작

**❓ Git, gh 설치 후에도 "명령을 찾을 수 없음"**
- PowerShell이 PATH를 새로 인식 못한 것. PowerShell 창 닫고 새로 열어 init.bat 다시 실행

**❓ import 후 Claude Desktop이 MCP를 못 찾음**
1. Claude Desktop을 **트레이 아이콘에서도** 완전히 종료 후 재시작
2. 그래도 안 되면 repo 폴더의 `backup/날짜시각/` 에서 원래 설정으로 복원 가능

**❓ 비밀 키를 잘못 입력함**
- repo 폴더의 `.env` 파일을 직접 열어 수정 → `pull.bat` 다시 더블클릭

**❓ 양쪽 PC에서 동시에 다른 변경을 push → git 충돌**
- 단방향 동기화 모델이라 양쪽 동시 작업은 권장하지 않음
- 충돌 시 GitHub 웹에서 해결하거나, 한쪽에서 `git pull --rebase` 후 다시 push

---

## 📁 파일 구조

```
claude-env-sync/
├── README.md              ← 이 파일
├── .gitignore             ← 보안 차단 목록
│
├── init.bat               ← 🏠 집 PC 첫 셋업 (더블클릭)
├── init.ps1               ← └─ 내부 로직
│
├── bootstrap.ps1          ← 💻 다른 PC 첫 셋업 (한 줄 명령)
│
├── push.bat               ← 🔁 평소 push (더블클릭)
├── pull.bat               ← 🔁 평소 pull (더블클릭)
│
├── export.ps1             ← 내부: 환경 백업
├── import.ps1             ← 내부: 환경 복원
│
├── snapshot/              ← export 결과 (git 추적됨)
├── .env.example           ← 비밀 키 자리표시자 (git 추적됨)
├── .env                   ← 실제 키 (git 제외)
└── backup/                ← 자동 백업 (git 제외)
```

---

## ✏️ 전체 흐름

```
                           [집 PC]
                              │
                              │  init.bat 더블클릭
                              ▼
        ┌──────────────────────────────────────┐
        │  1. Git, GitHub CLI 자동 설치        │
        │  2. GitHub 로그인 (브라우저, 1회)    │
        │  3. private repo 자동 생성           │
        │  4. C:\dev\에 clone                  │
        │  5. 환경 백업 + push                 │
        │  6. 다른 PC용 명령어를 클립보드 복사 │
        └──────────────────────────────────────┘
                              │
                              ▼
                          [GitHub]
                              │
                              ▼
                          [다른 PC]
                              │
                              │  PowerShell에 명령어 붙여넣기
                              ▼
        ┌──────────────────────────────────────┐
        │  1. 모든 도구 자동 설치              │
        │  2. GitHub 로그인 (브라우저, 1회)    │
        │  3. repo clone                       │
        │  4. API 키 입력                      │
        │  5. 모든 설정 자동 복원              │
        └──────────────────────────────────────┘

이후로는 양쪽에서 push.bat / pull.bat 더블클릭만 하면 됨
```
