---
name: google-sheets-expert
description: Google Sheets 한글 환경 최적화 스킬. sheets_get_values 오류 해결, 한글 시트명 처리, 네트워크 최적화. MCP google-sheets 도구 활용 전문가.
---

# Google Sheets Expert

한국어 환경에 최적화된 Google Sheets 전문 스킬입니다.

## 핵심 기능

### 1. sheets_get_values 오류 해결
- 작업 전 3단계 검증
- 자동 재시도 로직
- 오류 타입별 자동 복구

### 2. 한글 처리
- 한글 시트명에 작은따옴표 자동 적용: `'재고현황'!A1:B10`
- UTF-8 인코딩 보장
- 특수문자 자동 이스케이프

### 3. 네트워크 최적화
- 1,000행 이상 자동 분할
- Batch 작업 우선 활용
- 재시도 로직 (3초, 6초, 12초 대기)

## 사용 방법

### 작업 전 필수 확인

모든 작업 시작 전:
1. `sheets_list_spreadsheets` - 접근 가능 확인
2. `sheets_get_sheet_info` - 시트 정보 확인
3. 범위 유효성 검증

### 한글 시트명 처리

```
올바른 예:
'재고현황'!A1:B10
'2024년 1월'!A:C
'고객 문의사항'!B2:E100

잘못된 예:
재고현황!A1:B10  (작은따옴표 없음)
"재고현황"!A1:B10  (큰따옴표 사용)
```

### 범위 크기별 전략

```
소규모 (<1,000행): 직접 조회
중규모 (1,000~5,000행): 500행씩 분할
대규모 (>5,000행): 1,000행씩 batch 조회
```

## 오류 처리

### 400 Bad Request
- 범위 형식 자동 수정
- 시트명 작은따옴표 추가

### 403 Forbidden
- 사용자에게 공유 설정 안내

### 404 Not Found
- sheets_get_sheet_info로 시트명 확인
- 유사 시트명 제안

### 429 Rate Limit
- 3초 대기 후 자동 재시도
- 지수 백오프 적용

### Timeout
- 자동 범위 분할
- 진행 상황 표시

## MCP 도구 활용

### 데이터 읽기
```javascript
sheets_get_values(
    spreadsheet_id="1ABC...xyz",
    range="'재고현황'!A1:E100",
    value_render_option="FORMATTED_VALUE"
)
```

### Batch 조회
```javascript
sheets_batch_get_values(
    spreadsheet_id="1ABC...xyz",
    ranges=[
        "'재고현황'!A:E",
        "'판매현황'!A:D",
        "'요약'!A:B"
    ]
)
```

### 데이터 쓰기
```javascript
sheets_update_values(
    spreadsheet_id="1ABC...xyz",
    range="'재고현황'!A1:B2",
    values=[
        ["품목명", "수량"],
        ["노트북", "150"]
    ]
)
```

## 베스트 프랙티스

### DO
✅ 한글 시트명에 작은따옴표 사용
✅ sheets_get_sheet_info로 시트 확인
✅ 1,000행 이상 분할 조회
✅ Batch 작업 우선 활용
✅ 재시도 로직 적용

### DON'T
❌ 작은따옴표 생략
❌ 시트 확인 없이 조회
❌ 전체 시트 조회 (A:Z)
❌ 연속적인 단일 조회
❌ 검증 없이 대량 수정

## 실전 워크플로우

### 데이터 분석
```
1. sheets_list_spreadsheets - 스프레드시트 확인
2. sheets_get_sheet_info - 시트 정보 파악
3. sheets_get_values - 헤더 읽기
4. sheets_batch_get_values - 데이터 읽기 (분할)
5. 분석 수행
6. sheets_update_values - 결과 저장 (선택)
```

### 대량 데이터 수정
```
1. 백업 생성 (선택)
2. sheets_get_values - 수정 범위 확인
3. 데이터 가공
4. sheets_update_values - 분할 업데이트 (500행씩)
5. 검증
```

## 참고 자료

- guides/encoding-korean.md - 한글 처리 상세 가이드
- guides/error-handling.md - 오류 처리 전략
- guides/network-optimization.md - 성능 최적화
- references/mcp-tools-reference.md - MCP 도구 레퍼런스

---

Version: 2.0
Last Updated: 2026-02-02
Compatibility: Google Sheets MCP v1.0+
