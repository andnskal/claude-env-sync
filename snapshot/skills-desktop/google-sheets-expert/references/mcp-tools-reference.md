# Google Sheets MCP 도구 레퍼런스

## 📌 개요

Google Sheets MCP 서버에서 제공하는 모든 도구의 상세 레퍼런스입니다.

## 🔧 전체 도구 목록

```
[조회]
1. sheets_list_spreadsheets    - 스프레드시트 목록 조회
2. sheets_get_sheet_info        - 시트 정보 확인
3. sheets_get_values            - 데이터 읽기
4. sheets_batch_get_values      - 여러 범위 동시 읽기

[수정]
5. sheets_update_values         - 데이터 쓰기
6. sheets_append_values         - 데이터 추가
7. sheets_clear_values          - 데이터 지우기

[관리]
8. sheets_create_spreadsheet    - 새 스프레드시트 생성
9. sheets_add_sheet             - 시트 추가
```

---

## 1. sheets_list_spreadsheets

접근 가능한 스프레드시트 목록을 조회합니다.

### 파라미터

```javascript
{
  "max_results": 10  // 선택, 기본값 10
}
```

### 반환값

```json
[
  {
    "id": "1ABC...xyz",
    "name": "재고 관리",
    "url": "https://docs.google.com/spreadsheets/d/1ABC...xyz"
  },
  {
    "id": "1DEF...uvw",
    "name": "판매 현황",
    "url": "https://docs.google.com/spreadsheets/d/1DEF...uvw"
  }
]
```

### 사용 예시

```python
# 기본 사용
spreadsheets = sheets_list_spreadsheets()

# 더 많은 결과
spreadsheets = sheets_list_spreadsheets(max_results=20)

# 특정 스프레드시트 찾기
def find_spreadsheet_by_name(name):
    spreadsheets = sheets_list_spreadsheets(max_results=50)
    for sheet in spreadsheets:
        if name in sheet['name']:
            return sheet
    return None

target = find_spreadsheet_by_name("재고")
```

### 활용 팁

- 작업 시작 전 항상 실행하여 접근 가능 여부 확인
- 스프레드시트명으로 검색하여 ID 획득
- 권한 문제 진단에 활용

---

## 2. sheets_get_sheet_info

스프레드시트의 모든 시트 정보를 조회합니다.

### 파라미터

```javascript
{
  "spreadsheet_id": "1ABC...xyz"  // 필수
}
```

### 반환값

```json
{
  "spreadsheet_id": "1ABC...xyz",
  "title": "재고 관리",
  "sheets": [
    {
      "sheet_id": 0,
      "name": "재고현황",
      "index": 0,
      "grid_properties": {
        "row_count": 1000,
        "column_count": 26
      },
      "used_range": "A1:E665"
    },
    {
      "sheet_id": 123456,
      "name": "판매내역",
      "index": 1,
      "used_range": "A1:D324"
    }
  ]
}
```

### 사용 예시

```python
# 기본 사용
info = sheets_get_sheet_info("1ABC...xyz")

# 시트명 목록 추출
sheet_names = [s['name'] for s in info['sheets']]
print(f"사용 가능한 시트: {', '.join(sheet_names)}")

# 특정 시트 찾기
def find_sheet_by_name(info, sheet_name):
    for sheet in info['sheets']:
        if sheet['name'] == sheet_name:
            return sheet
    return None

재고_sheet = find_sheet_by_name(info, "재고현황")
if 재고_sheet:
    print(f"사용 범위: {재고_sheet['used_range']}")

# 실제 데이터 크기 파악
def get_data_dimensions(sheet):
    if 'used_range' in sheet:
        # A1:E665 → 665행, 5열
        range_str = sheet['used_range']
        end_cell = range_str.split(':')[1]
        # E665에서 행/열 추출
        col = ord(end_cell[0]) - ord('A') + 1
        row = int(end_cell[1:])
        return row, col
    return 0, 0

rows, cols = get_data_dimensions(재고_sheet)
print(f"데이터 크기: {rows}행 × {cols}열")
```

### 활용 팁

- 404 오류 발생 시 즉시 실행하여 시트명 확인
- 실제 사용 범위를 파악하여 불필요한 조회 방지
- 시트 존재 여부 사전 검증

---

## 3. sheets_get_values

지정된 범위의 데이터를 조회합니다.

### 파라미터

```javascript
{
  "spreadsheet_id": "1ABC...xyz",       // 필수
  "range": "'재고현황'!A1:E100",        // 필수
  "value_render_option": "FORMATTED_VALUE"  // 선택
}
```

### value_render_option 옵션

```
"FORMATTED_VALUE" (기본):
- 표시되는 대로 반환
- 날짜: "2024-01-15"
- 숫자: "1,000,000"
- 수식: 계산 결과

"UNFORMATTED_VALUE":
- 원본 값 반환
- 날짜: 44942 (엑셀 날짜 형식)
- 숫자: 1000000 (콤마 없음)
- 수식: 계산 결과

"FORMULA":
- 수식 그대로 반환
- 수식: "=SUM(A1:A10)"
- 일반 값: 그대로
```

### 반환값

```json
[
  ["품목명", "품목코드", "수량", "단가", "비고"],
  ["노트북", "NB-001", "150", "1200000", "정상"],
  ["모니터", "MN-002", "80", "350000", "재고부족"]
]
```

### 범위 지정 방법

```
[A] 특정 범위
'시트명'!A1:C10          ← A1부터 C10까지

[B] 전체 열
'시트명'!A:A             ← A열 전체
'시트명'!A:C             ← A, B, C열 전체

[C] 전체 행
'시트명'!1:1             ← 1행 전체
'시트명'!1:10            ← 1~10행 전체

[D] 전체 사용 범위
''                       ← 빈 문자열 (시트 전체)
또는 range 파라미터 없음

[E] 시트명 없이 (첫 번째 시트)
A1:C10

[F] 열 문자로만
A:C
```

### 사용 예시

```python
# 기본 사용
data = sheets_get_values(
    spreadsheet_id="1ABC...xyz",
    range="'재고현황'!A1:E100"
)

# 헤더만 조회
headers = sheets_get_values(
    spreadsheet_id="1ABC...xyz",
    range="'재고현황'!1:1"
)[0]

# 특정 열만 조회
수량_data = sheets_get_values(
    spreadsheet_id="1ABC...xyz",
    range="'재고현황'!C:C"
)

# 수식 조회
formulas = sheets_get_values(
    spreadsheet_id="1ABC...xyz",
    range="'재고현황'!A1:E10",
    value_render_option="FORMULA"
)

# 원본 값 조회 (숫자에서 콤마 제거)
raw_data = sheets_get_values(
    spreadsheet_id="1ABC...xyz",
    range="'재고현황'!D:D",
    value_render_option="UNFORMATTED_VALUE"
)

# 전체 사용 범위 조회
all_data = sheets_get_values(
    spreadsheet_id="1ABC...xyz",
    range=""  # 또는 range 생략
)
```

### 활용 팁

- 한글 시트명은 반드시 작은따옴표로 감싸기
- 1,000행 이상은 분할 조회 권장
- 헤더는 별도로 먼저 조회하여 구조 파악
- FORMATTED_VALUE는 사용자에게 보여줄 때
- UNFORMATTED_VALUE는 계산할 때 유용

---

## 4. sheets_batch_get_values

여러 범위를 한 번에 조회합니다.

### 파라미터

```javascript
{
  "spreadsheet_id": "1ABC...xyz",
  "ranges": [
    "'재고현황'!A:A",
    "'판매현황'!B:B",
    "'요약'!C1:C10"
  ]
}
```

### 반환값

```json
[
  [["노트북"], ["모니터"], ...],       // 첫 번째 범위 결과
  [["1000000"], ["2500000"], ...],    // 두 번째 범위 결과
  [["요약1"], ["요약2"], ...]         // 세 번째 범위 결과
]
```

### 사용 예시

```python
# 여러 시트 동시 조회
batch_data = sheets_batch_get_values(
    spreadsheet_id="1ABC...xyz",
    ranges=[
        "'재고현황'!A:E",
        "'판매현황'!A:D",
        "'고객정보'!A:C"
    ]
)

재고_data = batch_data[0]
판매_data = batch_data[1]
고객_data = batch_data[2]

# 같은 시트의 여러 열
columns = sheets_batch_get_values(
    spreadsheet_id="1ABC...xyz",
    ranges=[
        "'Sheet1'!A:A",
        "'Sheet1'!B:B",
        "'Sheet1'!C:C"
    ]
)

A열 = columns[0]
B열 = columns[1]
C열 = columns[2]

# 대용량 데이터 분할 조회
ranges = []
for i in range(1, 10001, 1000):
    ranges.append(f"'Sheet1'!A{i}:E{i+999}")

batch_data = sheets_batch_get_values(
    spreadsheet_id="1ABC...xyz",
    ranges=ranges
)

# 결과 통합
all_data = []
for chunk in batch_data:
    all_data.extend(chunk)
```

### 활용 팁

- 여러 시트/범위 조회 시 항상 사용 (성능 70% 향상)
- API 호출 횟수 감소 → Rate Limit 부담 완화
- 최대 범위 수: 제한 없음 (실전에서는 10개 이하 권장)

---

## 5. sheets_update_values

데이터를 씁니다 (기존 데이터 덮어쓰기).

### 파라미터

```javascript
{
  "spreadsheet_id": "1ABC...xyz",
  "range": "'재고현황'!A1:B2",
  "values": [
    ["품목명", "수량"],
    ["노트북", "150"]
  ],
  "value_input_option": "USER_ENTERED"  // 선택
}
```

### value_input_option 옵션

```
"USER_ENTERED" (기본):
- 수식 해석
- 입력: "=SUM(A1:A10)" → 수식으로 저장
- 입력: "2024-01-15" → 날짜로 인식
- 입력: "1,000" → 숫자 1000으로 인식

"RAW":
- 있는 그대로 저장
- 입력: "=SUM(A1:A10)" → 텍스트로 저장
- 입력: "2024-01-15" → 텍스트로 저장
- 입력: "1,000" → 텍스트로 저장
```

### 사용 예시

```python
# 기본 사용
sheets_update_values(
    spreadsheet_id="1ABC...xyz",
    range="'재고현황'!A1:B2",
    values=[
        ["품목명", "수량"],
        ["노트북", "150"]
    ]
)

# 수식 입력
sheets_update_values(
    spreadsheet_id="1ABC...xyz",
    range="'재고현황'!C2",
    values=[["=SUM(A2:B2)"]],
    value_input_option="USER_ENTERED"
)

# 텍스트로 강제 입력
sheets_update_values(
    spreadsheet_id="1ABC...xyz",
    range="'Sheet1'!A1",
    values=[["=이것은 수식이 아닙니다"]],
    value_input_option="RAW"
)

# 여러 행 업데이트
new_data = [
    ["노트북", "150", "1200000"],
    ["모니터", "80", "350000"],
    ["키보드", "200", "45000"]
]

sheets_update_values(
    spreadsheet_id="1ABC...xyz",
    range="'재고현황'!A2:C4",
    values=new_data
)

# 대량 업데이트 (분할)
def update_large_data(spreadsheet_id, sheet_name, data, chunk_size=500):
    for i in range(0, len(data), chunk_size):
        chunk = data[i:i+chunk_size]
        start_row = i + 2  # 헤더 제외
        end_row = start_row + len(chunk) - 1
        
        sheets_update_values(
            spreadsheet_id=spreadsheet_id,
            range=f"'{sheet_name}'!A{start_row}:C{end_row}",
            values=chunk
        )
        
        print(f"✅ {i+1}~{i+len(chunk)}행 업데이트 완료")
        time.sleep(0.5)  # Rate Limit 방지
```

### 활용 팁

- 헤더와 데이터를 함께 쓸 때 유용
- 기존 데이터를 완전히 덮어씀 (추가가 아님)
- 500행씩 분할하여 처리 권장
- 중요 데이터는 업데이트 전 백업

---

## 6. sheets_append_values

데이터를 추가합니다 (마지막 행 다음에).

### 파라미터

```javascript
{
  "spreadsheet_id": "1ABC...xyz",
  "range": "'로그'!A:C",  // 시작 범위
  "values": [
    ["2024-01-15", "완료", "재고 입력 완료"]
  ]
}
```

### 반환값

```json
{
  "spreadsheet_id": "1ABC...xyz",
  "updated_range": "'로그'!A101:C101",
  "updated_rows": 1,
  "updated_columns": 3
}
```

### 사용 예시

```python
# 로그 추가
sheets_append_values(
    spreadsheet_id="1ABC...xyz",
    range="'로그'!A:C",
    values=[
        [datetime.now(), "완료", "작업 완료"]
    ]
)

# 여러 행 추가
new_entries = [
    ["노트북", "NB-001", "150"],
    ["모니터", "MN-002", "80"],
    ["키보드", "KB-003", "200"]
]

sheets_append_values(
    spreadsheet_id="1ABC...xyz",
    range="'재고현황'!A:C",
    values=new_entries
)

# 실시간 로깅
def log_operation(spreadsheet_id, operation, status, message):
    sheets_append_values(
        spreadsheet_id=spreadsheet_id,
        range="'로그'!A:D",
        values=[[
            datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            operation,
            status,
            message
        ]]
    )

log_operation("1ABC...xyz", "데이터 조회", "성공", "100건 조회")
```

### 활용 팁

- 로그, 기록, 누적 데이터에 적합
- range는 시작 열만 지정 (예: A:C)
- 마지막 행을 자동으로 찾아 추가
- 헤더가 있어도 자동으로 데이터 행에 추가

---

## 7. sheets_clear_values

데이터를 지웁니다 (포맷은 유지).

### 파라미터

```javascript
{
  "spreadsheet_id": "1ABC...xyz",
  "range": "'Sheet1'!A1:C10"
}
```

### 사용 예시

```python
# 특정 범위 지우기
sheets_clear_values(
    spreadsheet_id="1ABC...xyz",
    range="'Sheet1'!A2:C10"
)

# 전체 시트 지우기 (헤더 제외)
sheets_clear_values(
    spreadsheet_id="1ABC...xyz",
    range="'재고현황'!A2:E"
)

# 데이터 초기화 (헤더 유지)
def reset_sheet(spreadsheet_id, sheet_name):
    # 시트 정보 확인
    info = sheets_get_sheet_info(spreadsheet_id)
    sheet = find_sheet_by_name(info, sheet_name)
    
    if sheet and 'used_range' in sheet:
        # A2부터 마지막까지 지우기
        range_str = f"'{sheet_name}'!A2:{sheet['used_range'].split(':')[1]}"
        sheets_clear_values(
            spreadsheet_id=spreadsheet_id,
            range=range_str
        )
        print(f"✅ {sheet_name} 시트 초기화 완료")
```

### 활용 팁

- 포맷(색상, 테두리 등)은 유지됨
- 수식도 삭제됨
- 시트 전체 지우기: A:Z 또는 1:1000
- 헤더 유지: A2부터 시작

---

## 8. sheets_create_spreadsheet

새 스프레드시트를 생성합니다.

### 파라미터

```javascript
{
  "title": "새 재고 관리",
  "sheet_names": ["재고현황", "판매내역", "요약"]  // 선택
}
```

### 반환값

```json
{
  "spreadsheet_id": "1NEW...xyz",
  "spreadsheet_url": "https://docs.google.com/spreadsheets/d/1NEW...xyz",
  "sheets": [
    {"name": "재고현황", "sheet_id": 0},
    {"name": "판매내역", "sheet_id": 123456},
    {"name": "요약", "sheet_id": 789012}
  ]
}
```

### 사용 예시

```python
# 기본 생성
new_sheet = sheets_create_spreadsheet(
    title="2024년 재고 관리"
)

print(f"생성됨: {new_sheet['spreadsheet_url']}")

# 여러 시트와 함께 생성
new_sheet = sheets_create_spreadsheet(
    title="고객 관리",
    sheet_names=["고객정보", "구매이력", "문의내역"]
)

# 생성 후 데이터 입력
spreadsheet_id = new_sheet['spreadsheet_id']

# 헤더 입력
sheets_update_values(
    spreadsheet_id=spreadsheet_id,
    range="'고객정보'!A1:C1",
    values=[["이름", "이메일", "전화번호"]]
)
```

### 활용 팁

- 생성된 스프레드시트는 자동으로 공유됨
- sheet_names 생략 시 "Sheet1"만 생성
- 생성 직후 ID를 저장하여 이후 작업에 사용

---

## 9. sheets_add_sheet

기존 스프레드시트에 시트를 추가합니다.

### 파라미터

```javascript
{
  "spreadsheet_id": "1ABC...xyz",
  "sheet_name": "2024년 1월"
}
```

### 반환값

```json
{
  "spreadsheet_id": "1ABC...xyz",
  "sheet_id": 987654,
  "sheet_name": "2024년 1월"
}
```

### 사용 예시

```python
# 기본 사용
sheets_add_sheet(
    spreadsheet_id="1ABC...xyz",
    sheet_name="2024년 2월"
)

# 월별 시트 생성
for month in range(1, 13):
    sheet_name = f"2024년 {month}월"
    sheets_add_sheet(
        spreadsheet_id="1ABC...xyz",
        sheet_name=sheet_name
    )
    print(f"✅ {sheet_name} 시트 생성")

# 생성 후 바로 데이터 입력
sheets_add_sheet(
    spreadsheet_id="1ABC...xyz",
    sheet_name="새 데이터"
)

sheets_update_values(
    spreadsheet_id="1ABC...xyz",
    range="'새 데이터'!A1:C1",
    values=[["컬럼1", "컬럼2", "컬럼3"]]
)
```

### 활용 팁

- 같은 이름의 시트가 있으면 오류 발생
- 시트명은 고유해야 함
- 생성 후 즉시 사용 가능

---

## 💡 종합 활용 예시

### 예시 1: 전체 워크플로우

```python
def complete_workflow():
    # 1. 스프레드시트 생성
    new_sheet = sheets_create_spreadsheet(
        title="재고 관리 시스템",
        sheet_names=["재고현황", "판매내역"]
    )
    
    spreadsheet_id = new_sheet['spreadsheet_id']
    
    # 2. 헤더 입력
    sheets_update_values(
        spreadsheet_id=spreadsheet_id,
        range="'재고현황'!A1:E1",
        values=[["품목명", "품목코드", "수량", "단가", "비고"]]
    )
    
    # 3. 데이터 입력
    sample_data = [
        ["노트북", "NB-001", "150", "1200000", "정상"],
        ["모니터", "MN-002", "80", "350000", "재고부족"]
    ]
    
    sheets_append_values(
        spreadsheet_id=spreadsheet_id,
        range="'재고현황'!A:E",
        values=sample_data
    )
    
    # 4. 확인
    result = sheets_get_values(
        spreadsheet_id=spreadsheet_id,
        range="'재고현황'!A:E"
    )
    
    print(f"✅ 완료! 총 {len(result)}행")
    print(f"URL: {new_sheet['spreadsheet_url']}")
```

---

**Version**: 1.0
**Last Updated**: 2026-02-02
**Related**: SKILL.md
