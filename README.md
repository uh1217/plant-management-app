# 식물 관리 앱 (PlantApp)

Firebase + Gemini AI 기반 반려식물 관리 Flutter 애플리케이션입니다.  
**RAG(Retrieval-Augmented Generation)** 기법을 활용한 AI 챗봇과 날씨 연동 식물 케어 추천을 핵심 기능으로 제공합니다.

---

## 주요 기능

| 기능 | 설명 |
|------|------|
| Google 로그인 / Firebase 인증 | 소셜 로그인 기반 사용자 인증 |
| 식물 CRUD | Firestore 기반 식물 등록·수정·삭제 |
| 물주기 · 비료 이력 관리 | 날짜 기록, 배지 표시, 일괄 처리 |
| 갤러리 | Firebase Storage 연동 식물별 사진 앨범 |
| **AI 원예 상담 챗봇 (RAG)** | Gemini + Firestore 식물 데이터 기반 멀티턴 챗봇 |
| **날씨 연동 케어 추천 (RAG)** | OpenWeatherMap + Gemini 기반 오늘의 식물 관리 알림 |
| 물주기 로컬 푸시 알림 | 설정한 시각에 매일 알림 |
| 라이트 / 다크 테마 | 기기 설정 연동 및 앱 내 전환 |

---

## RAG 시스템 상세

이 앱은 두 곳에서 **RAG(검색 증강 생성)** 방식으로 AI 응답을 생성합니다.  
벡터 DB나 임베딩 검색이 아닌 **전체 컨텍스트 주입(full-context injection)** 방식으로, 실시간 사용자 데이터를 AI 프롬프트에 직접 삽입합니다.

---

### 1. AI 원예 상담 챗봇 RAG

> 파일: `lib/core/services/gemini_service.dart`

```
사용자 메시지 전송
       │
       ▼
_buildRagContext(uid)          ← Firestore: users/{uid}/plants 전체 조회
       │
       ▼
식물 데이터 직렬화
  ├─ 이름, 카테고리, 물주기 주기
  ├─ 마지막 물준 날짜 → 경과 일수 / 다음 물주기까지 D-Day 계산
  ├─ 최근 비료 날짜
  └─ 증상·메모 (notes)
       │
       ▼
시스템 인스트럭션 + RAG 블록 + 사용자 질문 조합
       │
       ▼
Gemini ChatSession.sendMessage()   ← 멀티턴 대화 유지
       │
       ▼
AI 응답 반환
```

**주요 특징**

- **모델:** `gemini-2.0-flash` via `firebase_ai` (`FirebaseAI.googleAI()`)
- **멀티턴:** `ChatSession`을 유지하여 대화 맥락 보존
- **이미지 지원:** 갤러리 사진을 `InlineDataPart`로 첨부해 멀티모달 질문 가능
- **RAG 캐시:** UID별 **5분 캐시** — 식물 저장·삭제 시 `invalidateRagCache()`로 즉시 무효화
- **시스템 페르소나:** 한국어 원예 상담사 역할, `[ 사용자 등록 식물 정보 ]` 블록 우선 참조 규칙 포함
- **장애 내성:** Firestore 오류 시 빈 컨텍스트로 일반 답변 계속 진행

---

### 2. 날씨 연동 케어 추천 RAG

> 파일: `lib/core/services/weather_recommendation_service.dart`

```
GetWeatherRecommendationUseCase 호출
       │
       ├─── GPS 위치 조회 (LocationDataSource, 30분 캐시)
       │
       ├─── OpenWeatherMap /data/2.5/forecast 호출
       │         └─ 3시간 단위 16개 슬롯 → 오전(06~18시) / 오후(18~06시) 대표값 집계
       │              ├─ 우세 날씨 코드, 최고·최저 기온, 평균 습도, 최대 풍속
       │
       └─── HomeViewModel의 식물 목록(메모리) 필터링
                 ├─ 오늘 물줘야 할 식물 (daysUntil ≤ 0)
                 └─ 1~2일 내 물줘야 할 식물
       │
       ▼
_buildPrompt() — 날씨 + 식물 현황 구조화 텍스트 조합
       │
       ▼
Gemini generateContent()   ← 원샷(one-shot), 상태 없음
       │
       ▼
2~3문장 한국어 케어 메시지 반환 → WeatherRecommendationCard 표시
```

**주요 특징**

- **외부 API:** OpenWeatherMap Forecast 5-day/3-hour
- **슬롯 캐싱:** 오전(06:00) / 오후(18:00) 전환 시점에만 재요청
- **우선순위 규칙 (시스템 인스트럭션):**
  1. 물주기 급한 식물이 있으면 → 날씨 연계 물주기 조언
  2. 없으면 → 날씨 기반 일반 관리 팁
  3. 등록 식물 없으면 → 날씨 요약 + 등록 유도
- **원샷 방식:** `ChatSession` 없이 매 슬롯 독립 요청

---

### RAG 방식 비교

| 항목 | 챗봇 RAG | 날씨 RAG |
|------|----------|----------|
| 데이터 소스 | Firestore `users/{uid}/plants` | In-memory plants + OpenWeatherMap |
| 검색 방식 | 전체 컬렉션 로드 | 물주기 긴급도 필터링 |
| AI 호출 방식 | 멀티턴 `ChatSession` | 원샷 `generateContent` |
| 캐시 전략 | UID별 5분 TTL | 오전/오후 슬롯 기반 |
| 모델 역할 | 개인화 원예 상담사 | 오늘의 식물 케어 알리미 |

---

## 프로젝트 구조

```
lib/
├── main.dart                          # 앱 진입점, Firebase 초기화, 인증 게이트
├── core/
│   ├── di/
│   │   └── service_locator.dart       # 수동 의존성 주입 (싱글턴)
│   ├── result/
│   │   └── result.dart                # Result<T> (Success / Failure)
│   └── services/
│       ├── gemini_service.dart        # 챗봇 Gemini + Firestore RAG
│       ├── weather_recommendation_service.dart  # 날씨 AI + 식물 RAG
│       └── notification_service.dart  # 로컬 물주기 알림
├── Data/
│   ├── datasources/                   # Firebase · OpenWeatherMap · GPS 원격 소스
│   ├── models/                        # DTO (PlantDto, WeatherForecastDto 등)
│   ├── mappers/                       # DTO ↔ Domain Entity 변환
│   └── repositories_impl/            # Repository 구현체
├── Domain/
│   ├── entities/                      # Plant, ChatMessage, WeatherForecast 등
│   ├── repositories/                  # Repository 인터페이스
│   └── usecases/                      # 비즈니스 로직 단위
└── presentation/
    ├── viewmodels/                    # ChangeNotifier 기반 상태 관리
    ├── views/                         # 화면 (Home, Login, InputScreen)
    └── widgets/
        ├── plant_agent_dialog.dart          # 챗봇 UI (모달 다이얼로그)
        ├── weather_recommendation_card.dart  # 날씨 추천 카드
        ├── plant_list_card.dart
        ├── plant_gallery_dialog.dart
        └── app_sidebar.dart
```

---

## 기술 스택

| 분류 | 기술 |
|------|------|
| **Framework** | Flutter 3.x / Dart 3.x |
| **인증** | Firebase Auth + Google Sign-In |
| **DB** | Cloud Firestore |
| **스토리지** | Firebase Storage |
| **AI** | Gemini (`firebase_ai`, `gemini-2.0-flash`) |
| **날씨 API** | OpenWeatherMap Forecast 5-day/3-hour |
| **위치** | geolocator |
| **알림** | flutter_local_notifications + timezone |
| **이미지** | image_picker, flutter_image_compress, cached_network_image |
| **상태관리** | ChangeNotifier (ViewModel) |
| **설정 저장** | shared_preferences |
| **아키텍처** | Clean Architecture (Data / Domain / Presentation) |

---

## Firestore 데이터 모델

```
users/{uid}/
  └── plants/{plant_id}
        ├── name, image_url, categories[]
        ├── watering_frequency (days)
        ├── last_watered (timestamp)
        ├── watering_history[], fertilizer_history[]
        ├── notes (증상·메모)
        └── gallery/{photo_id}
              ├── photo_url
              ├── taken_at
              └── memo
```
