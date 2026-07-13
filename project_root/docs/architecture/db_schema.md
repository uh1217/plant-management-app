# Database Schema: Firestore

` ` `
전체 구조 데이터베이스 (Firestore)
 ┗ - users (루트 컬렉션: 사용자) 
    ┗ - {uid} (문서: 개별 사용자 식별자,Firebase Auth에서 발급한 고유 uid)
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
특징: 현재 단계에서는 별도의 사용자 정보(이름, 이메일 등) 필드를 저장하지 않고, 하위 컬렉션(plants)을 묶어주는 논리적인 그룹 역할만 수행합니다.

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
  watering_history: string[];   // 역대 물 주기 기록 (ISO 8601 배열, 최신 3개 유지)
  fertilizer_history: string[]; // 역대 비료 주기 기록 (ISO 8601 배열, 최신 3개 유지)
  pesticide_history: string[];  // 역대 농약 주기 기록 (ISO 8601 배열, 최신 3개 유지)
  notes?: string;               // 옵션: 흙 배합 등 커스텀 메모
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
