# Google Sheets 오류 처리 가이드

## 📌 개요

sheets_get_values 및 기타 MCP 도구 사용 시 발생하는 오류를 진단하고 해결하는 체계적인 가이드입니다.

## 🎯 오류 분류

### Level 1: 즉시 해결 가능 (자동 복구)
- 400 Bad Request (범위 오류)
- 429 Too Many Requests (Rate Limit)
- 일시적 네트워크 오류

### Level 2: 사용자 조치 필요
- 403 Forbidden (권한 문제)
- 404 Not Found (시트 없음)
- 인증 만료

### Level 3: 구조적 문제
- 스프레드시트 삭제됨
- MCP 서버 설정 오류
- API 할당량 소진

## 🚨 오류 타입별 대응

### 1. 400 Bad Request - 잘못된 요청

#### 원인
```
- 범위 형식 오류 (예: A1B10 대신 A1:B10)
- 시트명 인코딩 오류
- 존재하지 않는 열/행 참조
```

#### 증상
```
Error: Invalid range format
Error: Unable to parse range
Error: Invalid A1 notation
```

#### 해결 프로세스

```python
def handle_400_error(spreadsheet_id, original_range):
    """400 오류 자동 복구"""
    
    # Step 1: 범위 형식 검증
    if not ":" in original_range:
        # 단일 셀 → 범위로 확장
        fixed_range = f"{original_range}:{original_range}"
        return retry_with_range(spreadsheet_id, fixed_range)
    
    # Step 2: 시트명 검증
    if "!" in original_range:
        sheet_part, range_part = original_range.split("!")
        
        # 작은따옴표 확인
        if not (sheet_part.startswith("'") and sheet_part.endswith("'")):
            sheet_part = f"'{sheet_part.strip(\"'\")}')"
            fixed_range = f"{sheet_part}!{range_part}"
            return retry_with_range(spreadsheet_id, fixed_range)
    
    # Step 3: 시트 정보로 유효 범위 확인
    sheet_info = sheets_get_sheet_info(spreadsheet_id)
    # 시트의 실제 사용 범위 확인 후 조정
    
    # Step 4: 모두 실패 시 사용자에게 안내
    return {
        "error": "범위 형식 오류",
        "suggestion": "sheets_get_sheet_info로 시트 구조를 먼저 확인해주세요"
    }
```

#### 실전 예시

```
❌ 오류 발생:
sheets_get_values(
    range="재고현황!A1:B10"  # 작은따옴표 없음
)

✅ 자동 수정:
sheets_get_values(
    range="'재고현황'!A1:B10"  # 작은따옴표 추가
)

---

❌ 오류 발생:
sheets_get_values(
    range="'Sheet1'!A1:ZZ10000"  # 범위가 너무 큼
)

✅ 자동 수정:
# sheets_get_sheet_info로 실제 사용 범위 확인
# 예: A1:E665
sheets_get_values(
    range="'Sheet1'!A1:E665"
)
```

### 2. 403 Forbidden - 권한 없음

#### 원인
```
- 스프레드시트가 공유되지 않음
- 읽기 전용 권한만 있는데 쓰기 시도
- OAuth 토큰 권한 부족
```

#### 증상
```
Error: The caller does not have permission
Error: Insufficient permissions
Error: Access denied
```

#### 해결 프로세스

```
사용자에게 안내할 단계별 해결 방법:

[1단계] 공유 설정 확인
┌─────────────────────────────────────────┐
│ Google Sheets 파일 열기                  │
│ ↓                                        │
│ 우측 상단 "공유" 버튼 클릭                │
│ ↓                                        │
│ MCP 서버의 서비스 계정 이메일 추가       │
│ (또는 "링크가 있는 모든 사용자")          │
│ ↓                                        │
│ 권한 설정: "편집자" 또는 "뷰어"           │
└─────────────────────────────────────────┘

[2단계] 권한 확인
sheets_list_spreadsheets()
→ 해당 스프레드시트가 목록에 나타나는지 확인

[3단계] OAuth 재인증 (필요시)
Claude Desktop 재시작 또는
MCP 서버 재시작
```

#### 사용자 안내 메시지 템플릿

```
이 스프레드시트에 접근할 권한이 없습니다. 다음 방법으로 해결할 수 있습니다:

**방법 1: 공유 설정 (권장)**
1. Google Sheets에서 파일 열기
2. 우측 상단 "공유" 클릭
3. "링크가 있는 모든 사용자" 선택
4. 권한: "뷰어" (읽기만 필요) 또는 "편집자" (수정 필요)
5. "완료" 클릭

**방법 2: 스프레드시트 ID 재확인**
혹시 다른 스프레드시트를 열려고 하셨나요?
sheets_list_spreadsheets()로 접근 가능한 목록을 확인해드릴까요?
```

### 3. 404 Not Found - 시트/범위 없음

#### 원인
```
- 시트명 오타
- 시트가 삭제됨
- 스프레드시트 ID 오류
```

#### 증상
```
Error: Sheet not found
Error: Spreadsheet not found
Error: Unable to find sheet
```

#### 해결 프로세스

```python
def handle_404_error(spreadsheet_id, range_str):
    """404 오류 자동 복구"""
    
    # Step 1: 스프레드시트 존재 확인
    try:
        available = sheets_list_spreadsheets()
        if spreadsheet_id not in [s['id'] for s in available]:
            return {
                "error": "스프레드시트를 찾을 수 없습니다",
                "available": available,
                "suggestion": "위 목록에서 올바른 스프레드시트를 선택해주세요"
            }
    except:
        pass
    
    # Step 2: 시트 정보 확인
    try:
        sheet_info = sheets_get_sheet_info(spreadsheet_id)
        sheet_names = [s['name'] for s in sheet_info['sheets']]
        
        # 사용자가 요청한 시트명 추출
        if "!" in range_str:
            requested_sheet = range_str.split("!")[0].strip("'")
            
            # 유사한 시트명 찾기
            suggestions = find_similar_sheets(requested_sheet, sheet_names)
            
            return {
                "error": f"'{requested_sheet}' 시트를 찾을 수 없습니다",
                "available_sheets": sheet_names,
                "suggestions": suggestions
            }
    except:
        pass
    
    # Step 3: 범위만 문제인지 확인
    try:
        # 전체 범위로 조회 시도
        sheets_get_values(spreadsheet_id, range="")
        return {
            "error": "범위 지정 오류",
            "suggestion": "범위를 수정해주세요"
        }
    except:
        pass
    
    return {
        "error": "시트를 찾을 수 없습니다",
        "suggestion": "스프레드시트 ID와 시트명을 다시 확인해주세요"
    }

def find_similar_sheets(target, candidates):
    """유사한 시트명 찾기 (간단한 문자열 매칭)"""
    target_lower = target.lower()
    similar = []
    for candidate in candidates:
        if target_lower in candidate.lower():
            similar.append(candidate)
    return similar[:3]  # 최대 3개
```

#### 실전 예시

```
사용자 요청: "재고현왕 시트의 데이터를 보여줘"

[1단계] 404 오류 발생
sheets_get_values(range="'재고현왕'!A1:B10")
→ Error: Sheet not found

[2단계] 시트 정보 확인
sheets_get_sheet_info(spreadsheet_id)
→ 사용 가능 시트: ["Sheet1", "재고현황", "판매내역"]

[3단계] 유사 시트명 찾기
"재고현왕" vs ["Sheet1", "재고현황", "판매내역"]
→ 매칭: "재고현황" (유사도 높음)

[4단계] 사용자에게 확인
"'재고현왕' 시트를 찾을 수 없습니다.
혹시 '재고현황' 시트를 말씀하신 건가요?
[예] [아니오, 다른 시트]"
```

### 4. 429 Too Many Requests - Rate Limit

#### 원인
```
- API 호출 횟수 초과 (분당 100회)
- 짧은 시간 내 대량 요청
- 동시 다발적 API 호출
```

#### 증상
```
Error: Quota exceeded
Error: Rate limit exceeded
Error: Too many requests
```

#### 해결 프로세스

```python
def handle_429_with_retry(func, *args, max_retries=3, **kwargs):
    """Rate Limit 오류 자동 재시도"""
    
    for attempt in range(max_retries):
        try:
            return func(*args, **kwargs)
        except RateLimitError:
            if attempt < max_retries - 1:
                # 지수 백오프: 3초, 6초, 12초
                wait_time = (2 ** attempt) * 3
                print(f"⏳ API 호출 한도 도달. {wait_time}초 후 재시도... ({attempt + 1}/{max_retries})")
                time.sleep(wait_time)
            else:
                print("❌ 최대 재시도 횟수 초과. 잠시 후 다시 시도해주세요.")
                raise

# 사용 예시
result = handle_429_with_retry(
    sheets_get_values,
    spreadsheet_id="1ABC...xyz",
    range="'Sheet1'!A1:B10"
)
```

#### 예방 전략

```python
# 1. Batch 작업 활용
❌ 비효율적 (100번 호출):
for i in range(100):
    sheets_get_values(range=f"'Sheet1'!A{i}:A{i}")

✅ 효율적 (1번 호출):
sheets_get_values(range="'Sheet1'!A1:A100")

---

# 2. 호출 간 지연
for batch in data_batches:
    sheets_update_values(range=..., values=batch)
    time.sleep(0.5)  # 500ms 대기

---

# 3. Batch Get 활용
sheets_batch_get_values(
    ranges=[
        "'Sheet1'!A1:A100",
        "'Sheet2'!B1:B100",
        "'Sheet3'!C1:C100"
    ]
)
# 3번 호출 → 1번 호출로 감소
```

### 5. 네트워크 타임아웃

#### 원인
```
- 큰 범위 조회 (예: 10,000행)
- 느린 네트워크 연결
- Google API 서버 지연
```

#### 증상
```
Error: Request timeout
Error: Connection timeout
Error: Socket timeout
```

#### 해결 프로세스

```python
def handle_timeout_with_chunking(spreadsheet_id, large_range):
    """타임아웃 시 범위 분할"""
    
    # 범위 파싱
    # 예: 'Sheet1'!A1:Z10000 → sheet='Sheet1', start=A1, end=Z10000
    sheet, start, end = parse_range(large_range)
    
    # 행 범위 추출
    start_row = extract_row(start)  # 1
    end_row = extract_row(end)      # 10000
    
    # 500행씩 분할
    chunk_size = 500
    results = []
    
    for i in range(start_row, end_row + 1, chunk_size):
        chunk_start = i
        chunk_end = min(i + chunk_size - 1, end_row)
        
        chunk_range = f"'{sheet}'!A{chunk_start}:Z{chunk_end}"
        
        print(f"📊 조회 중: {chunk_start}~{chunk_end}행 ({len(results)*chunk_size}/{end_row}행)")
        
        try:
            chunk_data = sheets_get_values(
                spreadsheet_id=spreadsheet_id,
                range=chunk_range
            )
            results.extend(chunk_data)
            
            # Rate Limit 방지
            time.sleep(0.3)
            
        except TimeoutError:
            print(f"⚠️ {chunk_start}~{chunk_end}행 조회 실패. 재시도...")
            # 더 작은 단위로 재시도
            smaller_results = handle_timeout_with_chunking(
                spreadsheet_id,
                chunk_range
            )
            results.extend(smaller_results)
    
    return results
```

#### 실전 예시

```
사용자: "전체 데이터를 분석해줘" (15,000행)

[1단계] 직접 조회 시도
sheets_get_values(range="'Sheet1'!A1:Z15000")
→ Timeout (30초 초과)

[2단계] 자동 분할
15,000행 ÷ 500행 = 30개 청크

[3단계] 순차 조회
📊 조회 중: 1~500행 (0/15000행)
📊 조회 중: 501~1000행 (500/15000행)
📊 조회 중: 1001~1500행 (1000/15000행)
...
✅ 완료: 15,000행 조회 성공

[4단계] 결과 통합 및 분석
```

## 🔄 통합 오류 처리 워크플로우

```python
def safe_sheets_operation(operation, *args, **kwargs):
    """모든 오류를 처리하는 통합 래퍼"""
    
    max_attempts = 3
    
    for attempt in range(max_attempts):
        try:
            # 작업 수행
            result = operation(*args, **kwargs)
            return {
                "success": True,
                "data": result,
                "attempts": attempt + 1
            }
            
        except BadRequestError as e:
            # 400 오류 - 범위 수정 후 재시도
            if "range" in kwargs:
                fixed_range = fix_range_format(kwargs["range"])
                kwargs["range"] = fixed_range
                continue
            else:
                return {"success": False, "error": "범위 형식 오류", "details": str(e)}
        
        except ForbiddenError as e:
            # 403 오류 - 사용자 조치 필요
            return {
                "success": False,
                "error": "권한 없음",
                "action_required": "스프레드시트 공유 설정 확인 필요",
                "details": str(e)
            }
        
        except NotFoundError as e:
            # 404 오류 - 시트 확인
            sheet_info = sheets_get_sheet_info(kwargs.get("spreadsheet_id"))
            return {
                "success": False,
                "error": "시트 없음",
                "available_sheets": [s['name'] for s in sheet_info['sheets']],
                "details": str(e)
            }
        
        except RateLimitError as e:
            # 429 오류 - 대기 후 재시도
            if attempt < max_attempts - 1:
                wait_time = (2 ** attempt) * 3
                print(f"⏳ {wait_time}초 대기 후 재시도...")
                time.sleep(wait_time)
                continue
            else:
                return {"success": False, "error": "Rate Limit 초과", "details": str(e)}
        
        except TimeoutError as e:
            # Timeout - 범위 분할
            if "range" in kwargs and is_large_range(kwargs["range"]):
                print("📊 범위가 큽니다. 분할 조회를 시도합니다...")
                result = handle_timeout_with_chunking(
                    kwargs.get("spreadsheet_id"),
                    kwargs["range"]
                )
                return {"success": True, "data": result, "method": "chunked"}
            else:
                return {"success": False, "error": "Timeout", "details": str(e)}
        
        except Exception as e:
            # 예상치 못한 오류
            return {
                "success": False,
                "error": "알 수 없는 오류",
                "details": str(e),
                "type": type(e).__name__
            }
    
    # 모든 재시도 실패
    return {
        "success": False,
        "error": "최대 재시도 횟수 초과"
    }

# 사용 예시
result = safe_sheets_operation(
    sheets_get_values,
    spreadsheet_id="1ABC...xyz",
    range="'재고현황'!A1:B10"
)

if result["success"]:
    data = result["data"]
    # 데이터 처리
else:
    print(f"오류: {result['error']}")
    # 오류 처리
```

## 📊 오류 로깅 및 모니터링

```python
# 오류 발생 기록
error_log = []

def log_error(error_type, details, context):
    """오류 로깅"""
    error_log.append({
        "timestamp": datetime.now(),
        "type": error_type,
        "details": details,
        "context": context
    })

# 주기적 분석
def analyze_errors():
    """오류 패턴 분석"""
    error_counts = {}
    for error in error_log:
        error_type = error["type"]
        error_counts[error_type] = error_counts.get(error_type, 0) + 1
    
    print("=== 오류 발생 통계 ===")
    for error_type, count in error_counts.items():
        print(f"{error_type}: {count}회")
    
    # 가장 빈번한 오류
    most_common = max(error_counts, key=error_counts.get)
    print(f"\n가장 빈번한 오류: {most_common} ({error_counts[most_common]}회)")
    
    # 해결 제안
    if most_common == "400":
        print("→ 범위 형식 검증 강화 필요")
    elif most_common == "429":
        print("→ API 호출 빈도 감소 필요")
    elif most_common == "Timeout":
        print("→ 기본 분할 크기 축소 고려")
```

## 🎯 베스트 프랙티스

### ✅ DO

1. **항상 try-catch 사용**
   ```python
   try:
       result = sheets_get_values(...)
   except Exception as e:
       handle_error(e)
   ```

2. **재시도 로직 구현**
   ```python
   max_retries = 3
   for attempt in range(max_retries):
       try:
           return operation()
       except TransientError:
           if attempt < max_retries - 1:
               continue
   ```

3. **사용자 친화적 메시지**
   ```
   ❌ "Error 403"
   ✅ "스프레드시트 접근 권한이 없습니다. 공유 설정을 확인해주세요."
   ```

4. **오류 컨텍스트 제공**
   ```python
   {
       "error": "시트 없음",
       "requested": "재고현황",
       "available": ["Sheet1", "판매현황"]
   }
   ```

### ❌ DON'T

1. **무시하지 말기**
   ```python
   try:
       sheets_get_values(...)
   except:
       pass  # ✗ 절대 금지
   ```

2. **과도한 재시도**
   ```python
   while True:  # ✗ 무한 루프 금지
       try:
           sheets_get_values(...)
           break
       except:
           continue
   ```

3. **기술적 오류만 표시**
   ```
   ✗ "HTTPException: 403 Forbidden"
   ✓ "권한 부족. 공유 설정을 확인해주세요"
   ```

---

**Version**: 1.0
**Last Updated**: 2026-02-02
**Related**: SKILL.md, network-optimization.md
