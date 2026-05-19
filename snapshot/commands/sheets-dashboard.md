# Google Sheets 대시보드 프로젝트 생성 (하네스)

~/.claude/skills/sheets-dashboard.md 의 절차를 따른다.

## 절차

1. 사용자에게 필요 정보를 질문한다 (스킬 Step 1 참고)
2. 수집한 정보로 config.json 임시 파일을 생성한다
3. `npx create-next-app@latest` 로 Next.js 프로젝트를 생성한다
4. `npm install googleapis` 를 실행한다
5. **scaffold.mjs를 실행하여 모든 코드 파일을 자동 생성한다** (직접 작성 금지)
   ```
   node ~/.claude/templates/sheets-dashboard/scaffold.mjs --config {config} --out {project}
   ```
6. .env.local에 PRIVATE_KEY를 입력한다
7. npm run build 로 빌드를 확인한다
8. Git → GitHub → PR → Vercel 배포까지 완료한다

$ARGUMENTS
