# Database Schema: Firestore

` ` `
전체 구조 데이터베이스 (Firestore)
 ┗ - users (루트 컬렉션: 사용자) 
    ┗ - {uid} (문서: 개별 사용자 식별자,Firebase Auth에서 발급한 고유 uid)
       ┣ - 필드: care_defaults_created (기본 케어 버튼 생성 여부 플래그)
       ┣ - care_items (서브 컬렉션: 사용자 정의 비료/농약 버튼 - 계정 전체 공유)
       ┃  ┗ - {item_id} (문서: 개별 버튼, Firestore 자동 생성 난수 ID)
       ┃     ┗ - 필드: type, name, color, cycle_memo, include_watering, created_at
       ┗ - plants (서브 컬렉션: 사용자의 식물 목록)
          ┗ - {plant_id} (문서: 개별 식물 정보,Firestore 자동 생성 난수 ID)
             ┣ - 필드: name, imageUrl, categories, notes...
             ┣ - 필드 (배열): watering_history, fertilizer_history, pesticide_history...
             ┗ - gallery (서브-서브 컬렉션: 성장 앨범 사진)
                ┗ - {photo_id} (문서: 개별 사진 정보)
                   ┗ - 필드: photo_url, taken_at, memo...
` ` `

##Domain A: 사용자 도메인 (users)
역할: 개별 사용자의 독립적인 데이터 저장 공간 (개인 사물함 역할)
Document Key (ID): Firebase Auth에서 발급한 고유 uid (예: aB3x9Y...)
특징: 별도의 사용자 정보(이름, 이메일 등) 필드는 저장하지 않고, 하위 컬렉션(plants, care_items)을 묶어주는 논리적인 그룹 역할을 수행합니다.
care_defaults_created (boolean): 기본 케어 버튼("비료"/"농약") 생성 여부 플래그. 사용자가 모든 버튼을 삭제해도 기본 버튼이 재생성되지 않도록 별도 저장.

##Domain A-1: 케어 버튼 도메인 (care_items Collection)
경로: /users/{uid}/care_items
Document Key (ID): Firestore 자동 생성 난수 ID (item_id)
특징: 사용자가 등록한 비료/농약 버튼. 계정 전체 공유이며 삭제 시 버튼 문서만 제거되고 각 식물의 기록(스냅샷)은 유지된다. 최초 사용 시 기본 버튼 "비료"/"농약"이 각 1개 자동 생성된다.

` ` `typescript
// Collection: /users/{uid}/care_items
interface CareItemDocument {
  item_id: string;            // Firestore Auto ID
  type: 'fertilizer' | 'pesticide';
  name: string;               // 선택 (빈 문자열 허용, UI에서 '이름 없음' 표시)
  color: number;              // Flutter Color value (ARGB int)
  cycle_memo: string;         // 선택: 주기 메모 (자유 텍스트, 10자 이내)
  include_watering: boolean;  // true면 기록 시 물주기도 동시 갱신
  created_at: string;         // ISO 8601 (목록 정렬용)
}
` ` `

##Domain B: 식물 도메인 (plants Collection)
경로: /users/{uid}/plants
Document Key (ID): Firestore 자동 생성 난수 ID (plant_id)

` ` `typescript
// Collection: /users/{uid}/plants
interface PlantDocument {
  plant_id: string;             // Firestore Auto ID
  name: string;                 // 식물 이름 (예: 알로카시아 잭클린)
  image_url: string;            // Storage URL
  categories: string[];         // ['관엽', '괴근']
  watering_frequency: number;   // 권장 간격 (일 단위)
  last_watered: string;         // ISO 8601 DateTime
  watering_history: string[];   // 역대 물 주기 기록 (날짜 문자열 배열, 다음 쓰기 시 최신 3개)
  fertilizer_history: (string | CareRecord)[]; // 역대 비료 기록 (다음 쓰기 시 최신 5개)
  pesticide_history: (string | CareRecord)[];  // 역대 농약 기록 (다음 쓰기 시 최신 3개)
  notes?: string;               // 옵션: 흙 배합 등 커스텀 메모
}

// fertilizer_history / pesticide_history 배열 원소
// - 구버전: "YYYY-MM-DD" 문자열 (마이그레이션 없이 읽기 호환, UI에서 날짜만 표시)
// - 신버전: 케어 버튼 스냅샷 포함 맵 — 버튼 삭제 후에도 "이름(주기)" 표시 유지
// - 중복 판정: 같은 date + 같은 item_id
interface CareRecord {
  date: string;                 // YYYY-MM-DD (필수)
  item_id: string;              // 기록에 사용된 케어 버튼 ID
  name: string;                 // 버튼 이름 스냅샷
  cycle: string | null;         // 주기 메모 스냅샷
}
` ` `

##Domain C: 갤러리 도메인 (gallery Collection)
경로: /users/{uid}/plants/{plant_id}/gallery
Document Key (ID): Firestore 자동 생성 난수 ID (photo_id)

` ` `
// Sub-Collection: /users/{uid}/plants/{plant_id}/gallery
interface GalleryDocument {
  photo_id: string;             // Firestore Auto ID
  photo_url: string;            // Storage URL
  taken_at: string;             // ISO 8601 DateTime
  memo?: string;                // 옵션: 사진 메모
}
` ` `
