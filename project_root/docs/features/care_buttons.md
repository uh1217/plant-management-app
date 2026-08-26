# 기능 명세: 커스텀 비료/농약 버튼 (Care Buttons)

작성일: 2026-08-19
상태: 확정 (구현 전)

## 1. 개요

기존 비료/농약 기록은 날짜 문자열 1종류만 저장할 수 있어 여러 제품을 구분할 수 없었다.
이를 사용자가 직접 등록하는 "케어 버튼(care_item)" 단위로 확장한다.

- 버튼 = 사용자가 정의한 비료/농약 제품 객체 (계정 전체 공유)
- 기록 시 어떤 버튼(제품)으로 기록했는지 스냅샷과 함께 저장
- 기록 발생은 오직 바텀시트 안의 등록된 버튼을 탭했을 때만

## 2. 화면 흐름 (UI)

1. 홈 툴바에는 기존처럼 물주기 / 비료 / 농약 대표 버튼 3개가 항상 표시된다.
2. 식물 카드를 1개 이상 선택한 상태에서 비료(또는 농약) 대표 버튼을 누르면
   해당 타입의 **바텀시트**가 열린다. (선택된 식물이 없으면 비활성 — 현행 유지)
3. 바텀시트 구성:
   - 등록된 버튼 목록: 각 행 = 색 점 + `이름(주기)` + 우측 삭제 아이콘
   - 하단 `+ 새 버튼 추가` → 시트 내 폼으로 전환
   - 정렬: `created_at` 오름차순 (생성 순서)
4. **기록 동작**: 시트 안의 버튼 탭 → 선택된 식물 전체에 일괄 기록 → 시트 닫힘 → 스낵바 피드백.
   대표 버튼 자체는 시트를 여는 역할만 한다.
5. **버튼 추가 폼** 입력 항목:
   - 이름 (선택, 미입력 시 "이름 없음"으로 표시)
   - 색 (필수, 미리 정의된 팔레트에서 선택, 기본값 제공)
   - 주기 메모 (선택, 자유 텍스트, 10자 내외 제한)
   - **관수 여부** (체크박스, 기본 체크): 체크 시 이 버튼으로 기록할 때 물주기 로직도 함께 동작
   - 타입(비료/농약)은 열려 있는 시트에 따라 자동 결정 (별도 입력 없음)
6. **버튼 삭제**: 삭제 아이콘 탭 → **확인 다이얼로그 없이 즉시 삭제**.
   `care_items` 문서만 삭제되며, 기존 기록은 스냅샷 덕분에 그대로 유지·표시된다.
7. **기본 버튼**: 최초 사용 시 "비료", "농약" 버튼이 각 1개씩 자동 생성된다.
   (이름만 있고 주기 메모 없음, 관수 여부 = true → 기존 동작과 동일)

## 3. DB 스키마

### 3-1. 신규 컬렉션: care_items

경로: `/users/{uid}/care_items`
Document Key: Firestore 자동 생성 난수 ID (item_id)

```typescript
interface CareItemDocument {
  item_id: string;            // Firestore Auto ID
  type: 'fertilizer' | 'pesticide'; // 필수
  name: string;               // 선택 (빈 문자열 허용)
  color: number;              // 필수: Flutter Color value (ARGB int)
  cycle_memo: string;         // 선택 (빈 문자열 허용, 10자 내외)
  include_watering: boolean;  // 필수: true면 기록 시 물주기 동시 갱신
  created_at: string;         // ISO 8601 (정렬용)
}
```

### 3-2. 기록 포맷 변경: fertilizer_history / pesticide_history

필드 위치와 이름은 기존 그대로 (식물 문서 내 배열). 배열 **원소만 문자열 → 맵**으로 변경.

```jsonc
"fertilizer_history": [
  "2026-08-10",                     // 과거 기록 (문자열, 재작성하지 않고 방치)
  {                                 // 신규 기록 (항상 맵)
    "date": "2026-08-19",           // 필수 (YYYY-MM-DD)
    "item_id": "abc123",            // 버튼 ID (중복 판정용)
    "name": "하이포넥스",             // 스냅샷 (버튼 삭제 후에도 표시 유지)
    "cycle": "2주"                   // 스냅샷 (없으면 null/생략)
  }
]
```

- `watering_history`는 **기존 문자열 배열 포맷 그대로 유지** (물주기는 종류 개념 없음)
- 마이그레이션 없음: 과거 문자열 원소는 읽기 시에만 호환 처리

## 4. 동작 규칙

| 항목 | 규칙 |
|---|---|
| 기록 개수 제한 | 물 3 / 비료 5 / 농약 3 (배열 전체 기준 최신 N개). 관수 동시 기록 시 watering_history는 물 한도(3). 기존 문서는 다음 쓰기 전까지 그대로 |
| 중복 판정 | 같은 `date` + 같은 `item_id`면 무시. 같은 날 다른 버튼은 각각 기록 |
| 관수 여부 = true | 비료/농약 기록 + `watering_history` 추가 + `last_watered` 갱신 |
| 관수 여부 = false | 비료/농약 기록만. 물 관련 필드는 일절 건드리지 않음 |
| 트랜잭션 | 현행과 동일하게 서버 트랜잭션 안에서 읽기 → 추가 → 트리밍 → 쓰기 |
| 낙관적 업데이트 | 기록 성공 후 재조회 없이 로컬 상태에 동일 로직 반영 (현행 유지) |

## 5. 표시 규칙 (버튼 목록 · 날짜 히스토리 공통)

| 데이터 상태 | 표시 예 |
|---|---|
| 이름 O, 주기 O | `하이포넥스(2주)` |
| 이름 O, 주기 X | `하이포넥스` |
| 이름 X, 주기 O | `이름 없음(2주)` |
| 이름 X, 주기 X | `이름 없음` |
| 과거 문자열 기록 | 날짜만 (`2026-08-10`) |

히스토리 행 예: `2026-08-19  하이포넥스(2주)` (버튼 색 점 포함 가능)

## 6. 구현 체크리스트 (레이어별)

1. **domain**: `CareItem` 엔티티, `CareRecord` 값 객체(date, itemId?, name?, cycle?) 추가.
   `Plant.fertilizerHistory` / `pesticideHistory` 타입을 `List<String>` → `List<CareRecord>`로 변경
2. **data**: `CareItemDto` + 매퍼, `PlantDto` 파싱에 String/Map 분기 추가,
   `CareItemRemoteDataSource`(CRUD + 기본 버튼 생성),
   `PlantRemoteDataSource.fertilizePlant`/`pesticidePlant` 시그니처 변경
   (기록 정보 전달, 중복 판정 `date+item_id`, 종류별 한도, include_watering 분기)
3. **domain/usecases**: `GetCareItemsUseCase`, `AddCareItemUseCase`, `DeleteCareItemUseCase`,
   기존 fertilize/pesticide 유스케이스 파라미터 확장
4. **core/di**: ServiceLocator에 신규 의존성 등록
5. **presentation**: `HomeViewModel`에 careItems 상태 + `_trimHistory`의 CareRecord 버전 분리,
   바텀시트 위젯 신규 작성, `home_screen.dart` 대표 버튼 → 시트 연결,
   `plant_list_card.dart` 히스토리 렌더링을 CareRecord 기반으로 변경
6. **docs**: `db_schema.md`에 care_items 도메인 및 기록 포맷 변경 반영

## 7. 명시적으로 하지 않는 것 (Out of Scope)

- 버튼 편집(이름/색/주기 변경) 기능
- 과거 문자열 기록의 일괄 마이그레이션
- 주기 기반 알림 (주기 메모는 표시 전용 자유 텍스트)
- 버튼 삭제 시 확인 다이얼로그
