# 네트워크 최적화 가이드

## 📌 개요

Google Sheets API 호출을 최적화하여 타임아웃을 방지하고 작업 속도를 향상시키는 가이드입니다.

## 🎯 최적화 원칙

### 원칙 1: 필요한 데이터만 조회
```
❌ 비효율적:
sheets_get_values(range="'Sheet1'!A:Z")  # 26개 열 전체

✅ 효율적:
sheets_get_values(range="'Sheet1'!A:C")  # 필요한 3개 열만
```

### 원칙 2: Batch 작업 활용
```
❌ 비효율적 (3번 API 호출):
data1 = sheets_get_values(range="'Sheet1'!A:A")
data2 = sheets_get_values(range="'Sheet1'!B:B")
data3 = sheets_get_values(range="'Sheet1'!C:C")

✅ 효율적 (1번 API 호출):
all_data = sheets_get_values(range="'Sheet1'!A:C")
# 또는
batch_data = sheets_batch_get_values(ranges=[
    "'Sheet1'!A:A",
    "'Sheet1'!B:B",
    "'Sheet1'!C:C"
])
```

### 원칙 3: 범위 분할
```
큰 데이터는 청크로 나누기:

<1,000행: 직접 조회
1,000~5,000행: 500행씩 분할
>5,000행: 1,000행씩 분할 + 진행 상황 표시
```

## 📊 데이터 크기별 전략

### 소규모 데이터 (< 1,000행)

```python
# 직접 조회
result = sheets_get_values(
    spreadsheet_id="1ABC...xyz",
    range="'Sheet1'!A1:E1000"
)

# 시간: ~1-2초
# API 호출: 1회
```

**특징:**
- ✅ 단순하고 빠름
- ✅ 코드 간결
- ❌ 1,000행 초과 시 느려질 수 있음

### 중규모 데이터 (1,000~5,000행)

```python
def get_data_with_chunking(spreadsheet_id, sheet_name, end_row, chunk_size=500):
    """중규모 데이터를 청크로 조회"""
    
    all_data = []
    
    for start_row in range(1, end_row + 1, chunk_size):
        end = min(start_row + chunk_size - 1, end_row)
        
        chunk_range = f"'{sheet_name}'!A{start_row}:E{end}"
        
        print(f"📊 {start_row}~{end}행 조회 중...")
        
        chunk_data = sheets_get_values(
            spreadsheet_id=spreadsheet_id,
            range=chunk_range
        )
        
        all_data.extend(chunk_data)
        
        # Rate Limit 방지 (선택)
        time.sleep(0.2)
    
    print(f"✅ 총 {len(all_data)}행 조회 완료")
    return all_data

# 사용
data = get_data_with_chunking(
    spreadsheet_id="1ABC...xyz",
    sheet_name="재고현황",
    end_row=3000
)

# 시간: ~10-15초 (3,000행)
# API 호출: 6회 (500행씩)
```

**특징:**
- ✅ 안정적 (타임아웃 방지)
- ✅ 진행 상황 추적 가능
- ⚠️ API 호출 증가

### 대규모 데이터 (> 5,000행)

```python
def get_large_data_optimized(spreadsheet_id, sheet_name, end_row):
    """대규모 데이터 최적화 조회"""
    
    # 1. 먼저 sheets_get_sheet_info로 실제 사용 범위 확인
    sheet_info = sheets_get_sheet_info(spreadsheet_id)
    actual_range = find_used_range(sheet_info, sheet_name)
    
    print(f"📋 실제 사용 범위: {actual_range}")
    
    # 2. Batch 조회 준비 (1,000행씩)
    chunk_size = 1,000
    ranges = []
    
    for start_row in range(1, end_row + 1, chunk_size):
        end = min(start_row + chunk_size - 1, end_row)
        ranges.append(f"'{sheet_name}'!A{start_row}:{actual_range.split(':')[1][0]}{end}")
    
    # 3. Batch 조회 (한 번에 여러 범위)
    print(f"🚀 {len(ranges)}개 청크를 batch로 조회 중...")
    
    batch_results = sheets_batch_get_values(
        spreadsheet_id=spreadsheet_id,
        ranges=ranges
    )
    
    # 4. 결과 통합
    all_data = []
    for result in batch_results:
        all_data.extend(result)
    
    print(f"✅ 총 {len(all_data)}행 조회 완료")
    return all_data

# 사용
data = get_large_data_optimized(
    spreadsheet_id="1ABC...xyz",
    sheet_name="전체데이터",
    end_row=15000
)

# 시간: ~20-30초 (15,000행)
# API 호출: 1회 (batch 내부적으로 15개 범위)
```

**특징:**
- ✅ 매우 효율적 (batch 활용)
- ✅ 실제 사용 범위만 조회
- ✅ 대용량 안정 처리
- ⚠️ 복잡한 구현

## ⚡ Batch 작업 마스터하기

### sheets_batch_get_values 활용

```python
# 여러 시트, 여러 범위를 한 번에 조회
batch_result = sheets_batch_get_values(
    spreadsheet_id="1ABC...xyz",
    ranges=[
        "'재고현황'!A1:E100",
        "'판매현황'!A1:D200",
        "'요약'!A1:B10",
        "'로그'!A1:C50"
    ]
)

# 결과는 배열로 반환
재고_data = batch_result[0]
판매_data = batch_result[1]
요약_data = batch_result[2]
로그_data = batch_result[3]
```

**장점:**
- 🚀 4번 호출 → 1번 호출
- 🚀 총 시간 70% 단축
- ✅ Rate Limit 부담 감소

**주의사항:**
- 최대 범위 수: 제한 없음 (실전에서는 10개 이하 권장)
- 각 범위는 독립적으로 처리됨
- 하나의 범위가 실패해도 다른 범위는 정상 처리

### 실전 예시: 다중 시트 분석

```python
def analyze_multiple_sheets(spreadsheet_id):
    """여러 시트를 효율적으로 분석"""
    
    # 1. 필요한 모든 범위를 한 번에 조회
    ranges = [
        "'재고현황'!A:E",
        "'판매현황'!A:D",
        "'고객정보'!A:C",
        "'요약'!A:B"
    ]
    
    print("🚀 4개 시트 batch 조회 시작...")
    start_time = time.time()
    
    batch_data = sheets_batch_get_values(
        spreadsheet_id=spreadsheet_id,
        ranges=ranges
    )
    
    elapsed = time.time() - start_time
    print(f"✅ {elapsed:.1f}초 소요")
    
    # 2. 각 시트 데이터 처리
    재고_data = batch_data[0]
    판매_data = batch_data[1]
    고객_data = batch_data[2]
    요약_data = batch_data[3]
    
    # 3. 분석 수행
    analysis = {
        "재고_총계": sum_column(재고_data, 3),  # D열
        "판매_건수": len(판매_data) - 1,
        "고객_수": len(고객_data) - 1,
        "요약": 요약_data
    }
    
    return analysis

# 비교:
# 개별 조회: 4초 (각 1초 × 4회)
# Batch 조회: 1.2초 (70% 시간 단축)
```

## 🔄 재시도 전략

### 지수 백오프 (Exponential Backoff)

```python
def retry_with_backoff(func, max_retries=3, base_delay=1):
    """지수 백오프 재시도"""
    
    for attempt in range(max_retries):
        try:
            return func()
        except (NetworkError, TimeoutError) as e:
            if attempt < max_retries - 1:
                # 대기 시간: 1초, 2초, 4초
                delay = base_delay * (2 ** attempt)
                print(f"⏳ 네트워크 오류. {delay}초 후 재시도... ({attempt+1}/{max_retries})")
                time.sleep(delay)
            else:
                print(f"❌ {max_retries}회 재시도 실패")
                raise

# 사용
result = retry_with_backoff(
    lambda: sheets_get_values(
        spreadsheet_id="1ABC...xyz",
        range="'Sheet1'!A1:B10"
    )
)
```

### Jitter 추가 (충돌 방지)

```python
import random

def retry_with_jitter(func, max_retries=3):
    """Jitter(랜덤 대기)를 추가한 재시도"""
    
    for attempt in range(max_retries):
        try:
            return func()
        except Exception as e:
            if attempt < max_retries - 1:
                # 기본 대기 + 랜덤(0~1초)
                base_delay = 2 ** attempt
                jitter = random.uniform(0, 1)
                delay = base_delay + jitter
                
                print(f"⏳ {delay:.1f}초 후 재시도...")
                time.sleep(delay)
            else:
                raise

# 이점: 동시에 여러 작업 실행 시 충돌 방지
```

## 📈 진행 상황 표시

### 간단한 진행률

```python
def get_data_with_progress(spreadsheet_id, ranges):
    """진행률 표시와 함께 데이터 조회"""
    
    results = []
    total = len(ranges)
    
    for i, range_str in enumerate(ranges, 1):
        print(f"📊 진행 중: {i}/{total} ({i*100//total}%)")
        
        data = sheets_get_values(
            spreadsheet_id=spreadsheet_id,
            range=range_str
        )
        results.append(data)
        
        # 짧은 대기 (Rate Limit 방지)
        if i < total:
            time.sleep(0.3)
    
    print("✅ 완료!")
    return results
```

### 상세한 진행 상황

```python
def get_large_data_with_details(spreadsheet_id, sheet_name, total_rows, chunk_size=500):
    """상세한 진행 상황 표시"""
    
    import time
    
    all_data = []
    chunks = (total_rows + chunk_size - 1) // chunk_size
    start_time = time.time()
    
    for chunk_idx in range(chunks):
        start_row = chunk_idx * chunk_size + 1
        end_row = min((chunk_idx + 1) * chunk_size, total_rows)
        
        # 진행률 계산
        progress = (chunk_idx + 1) * 100 // chunks
        elapsed = time.time() - start_time
        rows_done = len(all_data)
        
        if rows_done > 0:
            rate = rows_done / elapsed
            remaining = (total_rows - rows_done) / rate
            eta_str = f"ETA: {remaining:.0f}초"
        else:
            eta_str = "계산 중..."
        
        print(f"📊 [{progress:3d}%] {start_row:5d}~{end_row:5d}행 | "
              f"{elapsed:.1f}초 경과 | {eta_str}")
        
        # 데이터 조회
        chunk_data = sheets_get_values(
            spreadsheet_id=spreadsheet_id,
            range=f"'{sheet_name}'!A{start_row}:E{end_row}"
        )
        all_data.extend(chunk_data)
        
        time.sleep(0.2)
    
    total_time = time.time() - start_time
    print(f"\n✅ 완료! 총 {total_rows}행 ({total_time:.1f}초 소요)")
    
    return all_data

# 출력 예시:
# 📊 [ 10%]     1~  500행 | 1.2초 경과 | ETA: 10초
# 📊 [ 20%]   501~ 1000행 | 2.5초 경과 | ETA: 10초
# 📊 [ 30%]  1001~ 1500행 | 3.8초 경과 | ETA: 9초
# ...
# ✅ 완료! 총 5000행 (12.3초 소요)
```

## 🎯 캐싱 전략

### 메모리 캐싱 (단순)

```python
# 전역 캐시
cache = {}

def get_values_cached(spreadsheet_id, range_str, ttl=300):
    """캐싱된 데이터 조회 (5분 TTL)"""
    
    cache_key = f"{spreadsheet_id}:{range_str}"
    
    # 캐시 확인
    if cache_key in cache:
        cached_data, cached_time = cache[cache_key]
        if time.time() - cached_time < ttl:
            print("💾 캐시에서 조회")
            return cached_data
    
    # 캐시 미스 - 실제 조회
    print("🌐 API 호출")
    data = sheets_get_values(
        spreadsheet_id=spreadsheet_id,
        range=range_str
    )
    
    # 캐시 저장
    cache[cache_key] = (data, time.time())
    
    return data

# 사용
data1 = get_values_cached("1ABC...xyz", "'Sheet1'!A:A")  # API 호출
data2 = get_values_cached("1ABC...xyz", "'Sheet1'!A:A")  # 캐시 조회
data3 = get_values_cached("1ABC...xyz", "'Sheet1'!A:A")  # 캐시 조회
# 3번 호출 → 1번 API 호출
```

### 파일 캐싱 (영구)

```python
import json
import hashlib
from pathlib import Path

def get_values_file_cached(spreadsheet_id, range_str, cache_dir="cache"):
    """파일 기반 캐싱"""
    
    # 캐시 디렉토리 생성
    Path(cache_dir).mkdir(exist_ok=True)
    
    # 캐시 키 생성
    cache_key = hashlib.md5(
        f"{spreadsheet_id}:{range_str}".encode()
    ).hexdigest()
    cache_file = Path(cache_dir) / f"{cache_key}.json"
    
    # 캐시 확인
    if cache_file.exists():
        print("💾 파일 캐시에서 조회")
        with open(cache_file, 'r', encoding='utf-8') as f:
            return json.load(f)
    
    # API 호출
    print("🌐 API 호출")
    data = sheets_get_values(
        spreadsheet_id=spreadsheet_id,
        range=range_str
    )
    
    # 캐시 저장
    with open(cache_file, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    
    return data

# 캐시 무효화
def invalidate_cache(spreadsheet_id, range_str, cache_dir="cache"):
    """캐시 삭제"""
    cache_key = hashlib.md5(
        f"{spreadsheet_id}:{range_str}".encode()
    ).hexdigest()
    cache_file = Path(cache_dir) / f"{cache_key}.json"
    if cache_file.exists():
        cache_file.unlink()
        print("🗑️ 캐시 삭제됨")
```

## 📊 성능 벤치마크

### 조회 방식별 비교 (5,000행 기준)

```
┌──────────────────────┬─────────┬───────────┬────────────┐
│ 방식                 │ 시간    │ API 호출  │ 안정성    │
├──────────────────────┼─────────┼───────────┼────────────┤
│ 전체 직접 조회       │ 15초    │ 1회       │ ⚠️ 낮음   │
│ 500행씩 분할         │ 25초    │ 10회      │ ✅ 높음   │
│ 1000행씩 분할        │ 20초    │ 5회       │ ✅ 높음   │
│ Batch (1000행씩)     │ 12초    │ 1회       │ ✅ 매우높음│
│ Batch + 캐싱         │ 0.5초   │ 0회       │ ✅ 매우높음│
└──────────────────────┴─────────┴───────────┴────────────┘

💡 권장: Batch (1000행씩) + 필요시 캐싱
```

### 여러 시트 조회 비교 (4개 시트)

```
┌──────────────────────┬─────────┬───────────┐
│ 방식                 │ 시간    │ API 호출  │
├──────────────────────┼─────────┼───────────┤
│ 순차 조회            │ 8초     │ 4회       │
│ Batch 조회           │ 2초     │ 1회       │
│ 절감                 │ -75%    │ -75%      │
└──────────────────────┴─────────┴───────────┘

💡 권장: 항상 sheets_batch_get_values 사용
```

## 🎯 베스트 프랙티스

### ✅ DO

1. **필요한 범위만 조회**
   ```python
   sheets_get_values(range="'Sheet1'!A:C")  # 3개 열
   ```

2. **Batch 작업 우선**
   ```python
   sheets_batch_get_values(ranges=[...])
   ```

3. **큰 범위는 분할**
   ```python
   # 1,000행씩
   for i in range(0, 10000, 1000):
       ...
   ```

4. **재시도 로직 구현**
   ```python
   retry_with_backoff(operation)
   ```

5. **진행 상황 표시**
   ```python
   print(f"진행: {i}/{total}")
   ```

6. **캐싱 활용**
   ```python
   get_values_cached(...)
   ```

### ❌ DON'T

1. **불필요하게 넓은 범위**
   ```python
   sheets_get_values(range="'Sheet1'!A:Z")  # ✗
   ```

2. **반복적인 단일 조회**
   ```python
   for col in ['A', 'B', 'C']:
       sheets_get_values(...)  # ✗
   ```

3. **재시도 없이 실패**
   ```python
   try:
       sheets_get_values(...)
   except:
       pass  # ✗
   ```

4. **Rate Limit 무시**
   ```python
   for _ in range(100):
       sheets_get_values(...)  # ✗ 즉시 호출
   ```

---

**Version**: 1.0
**Last Updated**: 2026-02-02
**Related**: SKILL.md, error-handling.md
