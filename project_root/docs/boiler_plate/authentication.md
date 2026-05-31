# Authentication (JWT & Session Strategy)

## 1. Token Management (토큰 관리 전략)
* **전략:** Stateless JWT 기반이나, 토큰의 발급/저장/갱신 주기는 100% Firebase SDK에 위임(Delegation)한다.
* **Access Token (ID Token):** 수명 1시간. Firebase가 메모리에서 관리.
* **Refresh Token:** 수명이 긴 토큰. OS 레벨의 안전한 저장소(iOS Keychain, Android EncryptedSharedPreferences)에 자동 보관.
* **Auto-Refresh:** Access Token 만료 시, 개발자의 개입 없이 Firebase SDK가 백그라운드에서 자동으로 토큰을 갱신한다.

## 2. Session Persistence (세션 유지)
* 별도의 로컬 스토리지(SharedPreferences 등)에 유저 정보를 수동으로 캐싱하지 않는다.
* 앱 재시작 시 `FirebaseAuth.instance.authStateChanges()` 스트림을 구독하여 자동으로 이전 세션을 복구하고 라우팅한다.

## 3. Cursor/AI 개발 원칙 (Core Rules)
1. **토큰 직접 조작 금지:** HTTP 요청이나 백엔드 통신 시, JWT를 파싱하거나 헤더에 직접 조립하는 코드를 작성하지 않는다. (Firebase SDK 내부 메서드 활용)
2. **상태 검증:** 만료 시간(Expiration)을 직접 계산하는 로직을 짜지 말고, `FirebaseAuth.instance.currentUser != null` 여부로만 로그인 세션을 판단한다.
3. **데이터베이스 보안:** 프론트엔드에서 JWT를 뜯어 권한을 검사하지 않는다. 모든 토큰 해독 및 권한(Role) 검사는 백엔드(Firestore Security Rules)의 `request.auth` 객체를 통해 처리한다.