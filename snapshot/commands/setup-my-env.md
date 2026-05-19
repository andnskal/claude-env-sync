# 내 Claude Code 환경 자동 세팅

이 명령어는 junhyeok의 Claude Code 환경을 자동으로 세팅합니다.
새 PC에서 Claude Code를 처음 설치한 후 `/setup-my-env` 를 입력하면 됩니다.

아래 작업을 순서대로 실행해주세요. 각 단계의 성공/실패를 한국어로 알려주세요.

---

## 1단계: 플러그인 설치

아래 플러그인들이 설치되어 있는지 확인하고, 없는 것만 설치해주세요.
마켓플레이스는 `claude-plugins-official`이며, 모두 `--scope user`로 설치합니다.

```bash
PLUGINS=(
  context7
  github
  frontend-design
  playwright
  typescript-lsp
  pyright-lsp
  code-review
  security-guidance
  code-simplifier
  commit-commands
)

for plugin in "${PLUGINS[@]}"; do
  if ! claude plugin list 2>/dev/null | grep -q "$plugin"; then
    claude plugin install "$plugin@claude-plugins-official" --scope user
  fi
done
```

## 2단계: MCP 서버 설치

아래 MCP 서버들을 확인하고 없으면 추가해주세요.

```bash
# filesystem
claude mcp list 2>/dev/null | grep -q "filesystem" || \
  claude mcp add filesystem -s user -- npx -y @modelcontextprotocol/server-filesystem "$HOME/Desktop"

# sequential-thinking
claude mcp list 2>/dev/null | grep -q "sequential-thinking" || \
  claude mcp add sequential-thinking -s user -- npx -y @modelcontextprotocol/server-sequential-thinking

# sqlite (pip install 필요)
claude mcp list 2>/dev/null | grep -q "sqlite" || {
  pip install mcp-server-sqlite 2>/dev/null
  claude mcp add sqlite -s user -- mcp-server-sqlite --db-path "$HOME/Documents/claude-mcp/database.db"
}
```

> 참고: google-sheets, pyhub.mcptools 같은 프로젝트별 MCP는 별도 안내합니다.

## 3단계: .bash_profile 자동 플러그인 스크립트 확인

`~/.bash_profile`에 아래 자동 플러그인 설치 스크립트가 있는지 확인해주세요.
없으면 파일 끝에 추가해주세요:

```bash
# >>> Claude Code 플러그인 자동 설치 >>>
# 새 PC에서도 터미널 열면 자동으로 플러그인을 확인하고 설치합니다.
if command -v claude &> /dev/null; then
  _claude_plugins=(
    frontend-design
    playwright
    typescript-lsp
    pyright-lsp
    code-review
    security-guidance
    code-simplifier
    commit-commands
    context7
    github
  )
  _installed=$(claude plugin list 2>/dev/null)
  for _p in "${_claude_plugins[@]}"; do
    if ! echo "$_installed" | grep -q "$_p"; then
      claude plugin install "$_p@claude-plugins-official" --scope user 2>/dev/null
    fi
  done
  unset _claude_plugins _installed _p
fi
# <<< Claude Code 플러그인 자동 설치 <<<
```

## 4단계: 결과 보고

모든 작업이 끝나면 아래 형식으로 결과를 보여주세요:

```
=== 환경 세팅 완료 ===

플러그인 (X/10):
  ✔ context7
  ✔ github
  ✔ frontend-design
  ✔ playwright
  ✔ typescript-lsp
  ✔ pyright-lsp
  ✔ code-review
  ✔ security-guidance
  ✔ code-simplifier
  ✔ commit-commands

MCP 서버:
  ✔ filesystem
  ✔ sequential-thinking
  ✔ sqlite

.bash_profile 자동 설치 스크립트: ✔ 설정됨
```
