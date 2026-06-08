# 식물 관리 앱 (PlantApp)

Firebase + Gemini AI 기반 반려식물 관리 Flutter 애플리케이션입니다.

## 주요 기능

- Google 로그인 / Firebase 인증
- Firestore 기반 식물 등록·물주기·비료 이력 관리
- Firebase AI Logic (Gemini) 기반 AI 원예 상담 챗봇 (이미지 질문 지원)
- 물주기 로컬 푸시 알림

## 프로젝트 구조

```
lib/
├── core/
│   ├── di/               # ServiceLocator (의존성 주입)
│   └── services/         # GeminiService, NotificationService
├── Data/
│   ├── datasources/      # Firebase · Gemini 원격 데이터 소스
│   └── repositories_impl/
├── domain/
│   ├── entities/
│   ├── repositories/
│   └── usecases/
└── presentation/
    ├── viewmodels/
    ├── views/
    └── widgets/
```

## 로컬 셋업 (클론 후 필수 작업)

이 저장소는 Firebase 설정 파일을 **gitignore 처리**했으므로 클론 후 아래 단계를 따라야 합니다.

### 1. Flutter 패키지 설치

```bash
flutter pub get
```

### 2. Firebase 프로젝트 연결

[Firebase Console](https://console.firebase.google.com/)에서 프로젝트를 생성하고
**FlutterFire CLI**로 설정 파일을 생성합니다.

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

> 이 명령이 아래 파일을 자동 생성합니다 (모두 gitignore됨):
> - `lib/firebase_options.dart`
> - `android/app/google-services.json`
> - `ios/Runner/GoogleService-Info.plist`

### 3. Firebase 서비스 활성화 (Firebase Console)

| 서비스 | 용도 |
|---|---|
| Authentication (Google 로그인) | 사용자 인증 |
| Firestore Database | 식물 데이터 저장 |
| Storage | 식물 사진 저장 |
| Firebase AI Logic (Gemini) | AI 원예 상담 |

### 4. Firestore 보안 규칙

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId}/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

### 5. 앱 실행

```bash
flutter run
```

## gitignore 처리된 파일 목록

| 파일 | 이유 |
|---|---|
| `lib/firebase_options.dart` | Firebase API 키 포함 |
| `android/app/google-services.json` | Firebase Android 설정 |
| `ios/Runner/GoogleService-Info.plist` | Firebase iOS 설정 |
| `android/key.properties` | 릴리즈 서명 키 비밀번호 |
| `*.keystore` / `*.jks` | Android 서명 키스토어 |

## 기술 스택

- **Flutter** 3.x / Dart 3.x
- **Firebase** (Auth, Firestore, Storage, AI Logic)
- **Gemini** (firebase_ai 패키지를 통한 멀티모달 AI)
- 아키텍처: Clean Architecture (Data / Domain / Presentation)
