# sheets-dashboard

Google Sheets MCP 도구를 최적화하여 시트 데이터를 읽고, 분석하고, 결과를 출력하는 스킬.
단일 컨텍스트 내에서 최소 MCP 호출로 최대 성능을 낸다.

## 트리거 조건

- Google Sheets URL이 포함된 요청
- "이 시트 읽어줘 / 분석해줘 / 정리해줘"
- "시트에 요약 추가해줘"
- "스프레드시트 데이터 확인해줘"
- 시트 ID가 포함된 모든 데이터 요청
- "/sheets-dashboard"

## 최우선 원칙: 원본 보호

- **원본 시트의 데이터, 수식, 서식을 절대 수정하지 않는다**
- 사용자가 "이 셀 수정해줘"처럼 **명시적으로 지시한 경우에만** 원본 수정 허용
- 분석/요약/수식 결과는 **항상 새 탭을 만들어서** 작성
- 새 탭 이름 규칙: `_분석_MMDD` 또는 `_요약_MMDD` (언더스코어 접두사로 원본과 구분)

## Step 1: Sheet ID 추출

URL에서 자동 추출한다. 사용자에게 ID를 물어보지 않는다.

```
https://docs.google.com/spreadsheets/d/{SHEET_ID}/edit...
                                        ^^^^^^^^^ 이 부분
```

## Step 2: 구조 파악 (MCP 1회차)

```
sheets_get_sheet_info(spreadsheet_id)
```

이 호출로 확인하는 것:
- 탭 이름 목록
- 각 탭의 행/열 크기
- 어떤 탭을 읽어야 하는지 판단

사용자가 탭을 지정하지 않았으면, 첫 번째 탭 또는 데이터가 있는 탭을 선택한다.

## Step 3: 데이터 읽기 (MCP 2회차)

**반드시 `batch_get_values`를 사용한다.** 헤더와 데이터를 한 번에 읽는다.

```
sheets_batch_get_values(
  spreadsheet_id,
  ranges: [
    "탭이름!1:2",              // 헤더 (1~2행, 병합 헤더 대비)
    "탭이름!A1:{lastCol}{lastRow}"  // 전체 데이터
  ]
)
```

### 범위 설정 규칙

- Step 2의 sheet_info에서 행/열 크기를 확인한 뒤 정확한 범위를 계산
- 500행 이하: 전체를 한 번에 읽기
- 500행 초과: 헤더 + 처음 500행을 읽고, 필요하면 추가 1회 호출
- 부족해서 재호출하는 것보다 넉넉하게 한 번에 읽는 게 낫다

### 절대 하지 말 것

- get_values로 헤더 따로, 데이터 따로 읽기 (2회 낭비)
- sheet_info 없이 추측으로 범위 설정 (재호출 위험)
- 좁은 범위로 조금씩 여러 번 읽기

## Step 4: 분석 및 출력

읽은 데이터를 분석한 뒤, 출력 형식을 결정한다.

### 출력 형식 결정 기준

사용자가 형식을 지정하지 않은 경우 아래 기본값을 따른다:

| 요청 패턴 | 기본 출력 |
|-----------|----------|
| "분석해줘 / 정리해줘 / 요약해줘" | **시트에 새 탭 추가** |
| "보여줘 / 확인해줘" | **마크다운 테이블** |
| "엑셀로 / 파일로" | **로컬 .xlsx 생성** |
| 모호한 경우 | **시트에 새 탭 추가** |

## 출력 패턴별 상세

### 패턴 A: 시트에 새 탭 추가 (가장 빈번)

```
1. sheets_add_sheet(spreadsheet_id, "_분석_0328")     // 새 탭 생성
2. sheets_update_values(                                // 수식/데이터 작성
     spreadsheet_id,
     range: "_분석_0328!A1",
     values: [...],
     value_input_option: "USER_ENTERED"                 // 수식 해석 필수
   )
```

수식 작성 규칙:
- 원본 시트를 참조하는 수식 사용 (예: `='재고이슈'!A2`)
- SUMIF, COUNTIF, VLOOKUP 등 시트 간 참조 수식 적극 활용
- 수식으로 해결 가능한 것은 수식으로 — 정적 값 복사 최소화
- 원본이 업데이트되면 분석 시트도 자동 반영되는 구조가 이상적
- `value_input_option`은 반드시 `"USER_ENTERED"` (수식 해석)

새 탭 구성 예시:
```
A1: "요약"                     (제목)
A2: "생성일: 2026-03-28"       (메타)
A4: "항목"  B4: "값"           (헤더)
A5: "전체 행 수"  B5: =COUNTA('원본시트'!A:A)-1
A6: "빈 값 수"    B6: =COUNTBLANK('원본시트'!B2:B100)
...
```

### 패턴 B: 마크다운 테이블

- 전체 데이터를 그대로 붙이지 않는다
- 핵심 지표/인사이트를 요약하고, 필요 시 원본 일부만 테이블로 표시
- 큰 데이터는 상위 N건 + 요약 통계로 축약

### 패턴 C: Excel 내보내기

pyhub_mcptools MCP 도구를 활용한다:

```
1. excel_set_values    → 데이터 작성
2. excel_set_styles    → 헤더 서식, 색상 적용
3. excel_autofit       → 열 너비 자동 조정
4. excel_add_chart     → 차트 추가 (필요 시)
```

저장 경로는 사용자에게 확인하거나, 작업 디렉토리에 `{시트이름}_분석_{MMDD}.xlsx`로 저장한다.

### 패턴 D: 원본 직접 수정 (명시적 지시 시에만)

```
1. sheets_get_values   → 수정 대상의 현재값 확인
2. 사용자에게 변경 내용을 보여주고 확인
3. sheets_update_values → 수정 실행
```

- 반드시 수정 전 현재값을 보여주고 확인받는다
- "B3을 X로 바꿔줘" 같은 명시적 지시가 있을 때만 실행
- 범위가 넓은 수정은 한 번 더 확인한다

## MCP 도구 참조

### google-sheets (읽기/쓰기)

| 도구 | 용도 | 사용 시점 |
|------|------|----------|
| `sheets_get_sheet_info` | 시트 구조 조회 | Step 2: 항상 첫 호출 |
| `sheets_batch_get_values` | 다중 범위 동시 읽기 | Step 3: 데이터 읽기 기본 |
| `sheets_get_values` | 단일 범위 읽기 | 작은 범위 확인 시에만 |
| `sheets_update_values` | 셀 쓰기 | 새 탭에 결과 작성 |
| `sheets_append_values` | 행 추가 | 기존 탭 끝에 추가 시 |
| `sheets_add_sheet` | 새 탭 생성 | 분석 결과 탭 생성 |
| `sheets_clear_values` | 범위 삭제 | 새 탭 초기화 시 |
| `sheets_create_spreadsheet` | 새 시트 생성 | 별도 시트 필요 시 |
| `sheets_list_spreadsheets` | 접근 가능 목록 | 시트 찾기 |

### pyhub_mcptools (Excel 내보내기)

| 도구 | 용도 |
|------|------|
| `excel_set_values` | .xlsx에 데이터 작성 |
| `excel_set_styles` | 서식 적용 |
| `excel_autofit` | 열 너비 자동 조정 |
| `excel_add_chart` | 차트 추가 |
| `excel_add_pivot_table` | 피벗 테이블 추가 |

## 서비스 계정

기본: `claude-sheets-service@claude-mcp-459815.iam.gserviceaccount.com`
- 읽기: 시트에 뷰어 이상 공유 필요
- 쓰기 (새 탭 등): 편집자 권한 필요
- 권한 없을 시 에러 → 사용자에게 공유 안내

## 성능 요약

| 항목 | 규칙 |
|------|------|
| 읽기 MCP 호출 | **2회 이내** (info → batch_get) |
| 원본 보호 | **명시 지시 없으면 수정 불가** |
| 결과 출력 | **새 탭 추가가 기본** |
| 수식 | **시트 간 참조 수식 우선, 정적 값 최소화** |
| 범위 설정 | **sheet_info 기반 정확한 범위, 넉넉하게** |
