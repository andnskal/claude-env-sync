# 한글 인코딩 완벽 가이드

## 📌 개요

Google Sheets에서 한글을 다룰 때 발생하는 인코딩 문제를 해결하는 상세 가이드입니다.

## 🎯 한글 처리의 3대 영역

### 1. 시트명 (Sheet Name)

#### ✅ 올바른 참조 방법

```
기본 규칙: 한글 시트명은 반드시 작은따옴표(')로 감싸기

예시:
'재고현황'!A1:B10           ✓ 올바름
'2024년 실적'!A:C           ✓ 올바름
'CS팀 데이터'!B2:D100       ✓ 올바름

재고현황!A1:B10             ✗ 오류 발생
"재고현황"!A1:B10           ✗ 큰따옴표는 안 됨
'재고현황!A1:B10            ✗ 닫는 따옴표 없음
```

#### 🔍 특수 케이스

**A. 작은따옴표가 포함된 시트명**
```
원본 시트명: "고객's 데이터"
올바른 참조: '고객''s 데이터'!A1:B10
            (작은따옴표를 두 번 연속 사용)
```

**B. 공백이 포함된 시트명**
```
원본 시트명: "주간 보고서"
올바른 참조: '주간 보고서'!A1:B10
            (반드시 작은따옴표 사용)
```

**C. 숫자로 시작하는 시트명**
```
원본 시트명: "2024년 1월"
올바른 참조: '2024년 1월'!A1:B10
            (반드시 작은따옴표 사용)
```

**D. 특수문자 포함**
```
하이픈: '2024-01-15'!A1:B10
슬래시: 'CS/영업팀'!A1:B10
괄호: '데이터(최종)'!A1:B10
```

### 2. 헤더 (Header Row)

#### 📊 한글 헤더 읽기

```python
# 헤더 조회
sheets_get_values(
    spreadsheet_id="1ABC...xyz",
    range="'재고현황'!1:1",
    value_render_option="FORMATTED_VALUE"
)

# 예상 결과:
[["품목명", "품목코드", "수량", "단가", "비고"]]
```

#### 🎯 헤더 기반 데이터 접근

```python
# 1단계: 헤더 읽기
headers = sheets_get_values(range="'시트'!1:1")[0]
# ["품목명", "품목코드", "수량"]

# 2단계: 원하는 컬럼 찾기
수량_인덱스 = headers.index("수량")  # 2 (C열)

# 3단계: 해당 컬럼 데이터 조회
column_letter = chr(65 + 수량_인덱스)  # 'C'
sheets_get_values(range=f"'시트'!{column_letter}2:{column_letter}100")
```

#### ⚠️ 주의사항

```
한글 헤더 비교 시 주의:
- 공백 차이: "품목명" ≠ "품목명 " (끝에 공백)
- 전각/반각: "품목명" ≠ "품목명" (전각 공백)
- 대소문자: 한글은 대소문자 구분 없음

해결책: 비교 전 trim() 및 normalize() 처리
```

### 3. 데이터 (Cell Data)

#### 📝 한글 데이터 읽기

```javascript
sheets_get_values(
    spreadsheet_id="1ABC...xyz",
    range="'재고현황'!A2:E10",
    value_render_option="FORMATTED_VALUE"  // 중요!
)

// 올바른 결과:
[
    ["노트북", "NB-001", "150", "1,200,000", "정상"],
    ["모니터", "MN-002", "80", "350,000", "재고부족"],
    ...
]
```

#### 💾 한글 데이터 쓰기

```javascript
sheets_update_values(
    spreadsheet_id="1ABC...xyz",
    range="'재고현황'!A2:C2",
    values=[
        ["노트북", "NB-001", "150"]
    ],
    value_input_option="USER_ENTERED"
)
```

## 🔧 인코딩 문제 해결 프로세스

### Step 1: 문제 진단

```
증상별 체크리스트:

□ sheets_get_values 오류?
  → 시트명 인코딩 문제 가능성 높음
  
□ 데이터가 ??? 또는 깨진 문자로 표시?
  → value_render_option 설정 확인
  
□ 특정 시트만 접근 안 됨?
  → 시트명에 특수문자나 공백 확인

□ 영문 시트는 되는데 한글 시트만 안 됨?
  → 작은따옴표 누락 확인
```

### Step 2: 해결 시도

```python
# 시도 1: 표준 방법
sheets_get_values(
    spreadsheet_id="1ABC...xyz",
    range="'재고현황'!A1:B10"
)

# 실패 시 시도 2: 시트 정보로 정확한 이름 확인
sheet_info = sheets_get_sheet_info(spreadsheet_id="1ABC...xyz")
# sheet_info에서 정확한 시트명 복사

# 시도 3: 시트 인덱스 사용
# Google Sheets는 시트를 0부터 시작하는 인덱스로도 참조 가능
# (단, MCP 도구에서 직접 지원하지 않을 수 있음)

# 시도 4: 시트명 단순화
# 사용자에게 시트명을 영문으로 변경하도록 요청
```

### Step 3: 폴백 전략

```
Priority 1: 한글 시트명 with 작은따옴표
'재고현황'!A1:B10

Priority 2: 시트 정보에서 복사한 정확한 이름
sheets_get_sheet_info()로 얻은 이름 그대로 사용

Priority 3: 영문 시트명으로 변경 요청
사용자에게 시트명을 "Inventory" 등으로 변경 요청

Priority 4: 새 시트에 데이터 복사
sheets_add_sheet()로 영문 시트 생성 후 데이터 복사
```

## 📋 실전 케이스 스터디

### 케이스 1: 복잡한 한글 시트명

```
상황: "2024년 1분기 CS팀 실적 (최종본)" 시트 접근

해결:
sheets_get_values(
    spreadsheet_id="1ABC...xyz",
    range="'2024년 1분기 CS팀 실적 (최종본)'!A1:E100"
)

주의사항:
- 괄호 포함: 괄호도 작은따옴표 안에 포함
- 공백 여러 개: 공백도 정확히 일치해야 함
```

### 케이스 2: 한글-영문 혼합 헤더

```
상황: ["Product Name", "제품코드", "Quantity", "가격"]

조회 방법:
headers = sheets_get_values(range="'Sheet1'!1:1")[0]

# 한글 헤더 찾기
제품코드_인덱스 = headers.index("제품코드")  # 1
가격_인덱스 = headers.index("가격")        # 3

# 해당 컬럼만 조회
sheets_batch_get_values(
    ranges=[
        f"'Sheet1'!B2:B100",  # 제품코드
        f"'Sheet1'!D2:D100"   # 가격
    ]
)
```

### 케이스 3: 한글 데이터 대량 입력

```
상황: 1,000개 한글 품목명 입력

방법:
# 500개씩 분할
data_chunk1 = [
    ["노트북"], ["모니터"], ... # 500개
]
data_chunk2 = [
    ["키보드"], ["마우스"], ... # 500개
]

sheets_update_values(
    range="'재고'!A2:A501",
    values=data_chunk1
)

# 1초 대기 (Rate Limit 방지)
time.sleep(1)

sheets_update_values(
    range="'재고'!A502:A1001",
    values=data_chunk2
)
```

## 🎯 베스트 프랙티스

### ✅ DO

1. **항상 작은따옴표 사용**
   ```
   '시트명'!범위
   ```

2. **value_render_option 명시**
   ```javascript
   value_render_option="FORMATTED_VALUE"
   ```

3. **시트 정보 먼저 확인**
   ```javascript
   sheets_get_sheet_info(spreadsheet_id)
   ```

4. **범위는 명확하게**
   ```
   'Sheet1'!A1:C100  // 명확함
   ```

5. **데이터 검증**
   ```python
   result = sheets_get_values(...)
   if result and len(result) > 0:
       # 데이터 처리
   ```

### ❌ DON'T

1. **작은따옴표 생략**
   ```
   재고현황!A1:B10  // ✗
   ```

2. **큰따옴표 사용**
   ```
   "재고현황"!A1:B10  // ✗
   ```

3. **불필요하게 넓은 범위**
   ```
   '시트'!A:Z  // 26개 열 전체 - 비효율
   ```

4. **인코딩 무시**
   ```python
   # 한글 체크 없이 바로 사용 - 위험
   sheet_name = user_input
   range = f"{sheet_name}!A1:B10"
   ```

## 🔍 디버깅 가이드

### 문제: "Sheet not found" 오류

```
체크리스트:
1. 작은따옴표 확인
   '재고현황'!A1:B10  (O)
   재고현황!A1:B10    (X)

2. 시트명 정확성
   sheets_get_sheet_info()로 실제 이름 확인

3. 공백/특수문자
   '재고 현황'  vs  '재고현황'
   띄어쓰기 정확히 일치?

4. 대소문자 (영문 시트명의 경우)
   'Sheet1'  vs  'sheet1'
```

### 문제: 한글이 깨져 보임

```
해결책:
1. value_render_option 확인
   "FORMATTED_VALUE" 사용

2. 터미널/브라우저 인코딩
   UTF-8 설정 확인

3. 출력 방식
   print(data)  대신
   json.dumps(data, ensure_ascii=False)
```

## 📚 추가 리소스

### Python 예제

```python
# UTF-8 강제
import sys
sys.stdout.reconfigure(encoding='utf-8')

# 한글 시트명 안전하게 처리
def safe_sheet_range(sheet_name, range_str):
    # 작은따옴표로 감싸기
    if not sheet_name.startswith("'"):
        sheet_name = f"'{sheet_name}'"
    if not sheet_name.endswith("'"):
        sheet_name = f"{sheet_name}'"
    return f"{sheet_name}!{range_str}"

# 사용
range_name = safe_sheet_range("재고현황", "A1:B10")
# 결과: '재고현황'!A1:B10
```

### JavaScript 예제

```javascript
// 한글 시트명 이스케이프
function escapeSheetName(name) {
  // 작은따옴표가 있으면 두 번 표시
  name = name.replace(/'/g, "''");
  // 작은따옴표로 감싸기
  return `'${name}'`;
}

// 사용
const sheetName = escapeSheetName("고객's 데이터");
const range = `${sheetName}!A1:B10`;
// 결과: '고객''s 데이터'!A1:B10
```

---

**Version**: 1.0
**Last Updated**: 2026-02-02
**Related**: SKILL.md, error-handling.md
