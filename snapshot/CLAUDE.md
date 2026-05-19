# Claude Code 글로벌 설정

## 사용 가능한 스킬

### /sheets-dashboard
Google Sheets MCP 도구를 최적화하여 시트를 읽고, 분석하고, 결과를 출력하는 스킬.
상세 가이드: ~/.claude/skills/sheets-dashboard.md

핵심 규칙:
- 원본 시트 절대 수정 금지 (명시적 지시 없는 한)
- 읽기는 MCP 2회 이내 (sheet_info → batch_get_values)
- 분석 결과는 항상 새 탭에 작성 (`_분석_MMDD`)
- 출력 형식 미지정 시 시트 새 탭 추가가 기본
- 수식은 시트 간 참조 우선, 정적 값 최소화

트리거: Google Sheets URL, 시트 읽기/분석/정리/요약 요청

## 공통 설정

- Git 사용자: andnskal / andnskal@users.noreply.github.com
- GitHub 계정: andnskal
- Vercel 조직: andnskals-projects
- Google Cloud 서비스 계정: claude-sheets-service@claude-mcp-459815.iam.gserviceaccount.com
- 기본 언어: 한국어 (ko)

