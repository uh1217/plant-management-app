import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// Firebase Auth + Google Sign-In 원격 데이터 소스- 로그인 및 인증 데이터
class AuthRemoteDataSource {
  AuthRemoteDataSource({
    //테스트 환경 고려 (실제 실행시 auth,googleSignIn 가져옴)
    FirebaseAuth? auth, //파이어베이스 인증 객체 (uid 발급) - 2단계 인증
    GoogleSignIn? googleSignIn, //구글 계정 맞는지 확인 (idToken 입장권 발급) - 1단계 인증
  })  : _auth = auth ?? FirebaseAuth.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;

  /// google_sign_in v7은 initialize를 정확히 한 번만 호출해야 한다.
  Future<void>? _initFuture;

  //Stream : 데이터가 흐르는 파이프라인 (유저가 로그인/로그아웃 시 파이어베이스가 실시간으로 상태 보내줌)
  Stream<String?> get authStateChanges =>
      _auth.authStateChanges().map((user) => user?.uid); //map을 활용해 uid만 전달

  Future<void> _ensureInitialized() {
    return _initFuture ??= _googleSignIn.initialize();
  }

  Future<String> signInWithGoogle() async {
    await _ensureInitialized();

    //유저가 구글 계정 선택 창을 띄우고 취소하면 에러를 던져 흐름 끊음
    final GoogleSignInAccount googleUser;
    try {
      googleUser = await _googleSignIn.authenticate();
    } on GoogleSignInException catch (e) {
      debugPrint(
        '[Auth] GoogleSignInException code=${e.code} description=${e.description}',
      );
      rethrow;
    }

    // 구글이 허용하면 파이어베이스가 알 수 있는 입장권으로 바꿈
    final googleAuth = googleUser.authentication;
    final idToken = googleAuth.idToken;
    if (idToken == null || idToken.isEmpty) {
      // serverClientId(웹 OAuth 클라이언트) 미설정·SHA 불일치 시 idToken이 비는 경우가 많다.
      throw StateError(
        'Google idToken이 비어 있습니다. Firebase에 Play 앱 서명 SHA-1/SHA-256이 '
        '등록돼 있는지, google-services.json에 web OAuth client(client_type: 3)가 '
        '있는지 확인하세요.',
      );
    }

    final credential = GoogleAuthProvider.credential(idToken: idToken);
    //그 입장권으로 파이베이스 서버에 로그인하고, 최종 성공하면 유저 고유 아이디 (uid) 반환
    final userCredential =
        await _auth.signInWithCredential(credential); // 입장권으로 Firebase 로그인
    final uid = userCredential.user?.uid;
    if (uid == null) {
      throw StateError('Firebase user is null after sign-in');
    }
    return uid;
  }

  //파이어베이스 뿐 아니라 구글 로그인 세션까지 완전히 연결 끊어버림
  Future<void> signOut() async {
    // iOS(Apple 로그인 전용)처럼 Google 클라이언트가 설정되지 않은 환경에서는
    // initialize가 실패할 수 있으므로, Google 로그아웃 실패가
    // Firebase 로그아웃까지 막지 않도록 분리한다
    try {
      await _ensureInitialized();
      // disconnect는 계정 연결 해제로 재동의 팝업을 유발할 수 있어 signOut만 사용
      await _googleSignIn.signOut();
    } catch (e) {
      debugPrint('[Auth] Google signOut 건너뜀: $e');
    }
    await _auth.signOut();
  }

  /// Apple ID 로그인 (iOS 전용)
  /// nonce: 중간자 공격 방지용 1회성 랜덤 문자열
  ///   - 원본 nonce → Firebase에 전달
  ///   - SHA-256 해시 → Apple에 전달
  /// Apple은 응답 토큰에 해시를 포함시켜 반환 → Firebase가 원본으로 검증
  Future<String> signInWithApple() async {
    // ① Apple 인증 → Firebase Credential 생성 (재인증과 공용 헬퍼)
    final (appleCredential, oauthCredential) = await _getAppleOAuthCredential();

    // ② Firebase 로그인 → uid 반환
    final userCredential = await _auth.signInWithCredential(oauthCredential);
    final user = userCredential.user;
    if (user == null) {
      throw StateError('Firebase user is null after Apple sign-in');
    }

    // ③ Apple은 "최초 로그인 딱 한 번"만 이름을 제공 → 이때 저장하지 않으면 영구 유실
    await _saveAppleDisplayNameIfNeeded(user, appleCredential);
    return user.uid;
  }

  /// Apple 인증 창을 띄우고 (Apple 원본 응답, Firebase용 Credential) 쌍을 반환.
  /// 로그인과 탈퇴 전 재인증에서 공용으로 사용한다.
  Future<(AuthorizationCredentialAppleID, OAuthCredential)>
      _getAppleOAuthCredential() async {
    final rawNonce = _generateNonce();
    final hashedNonce = _sha256ofString(rawNonce);

    // 최초 로그인 시에만 email·fullName이 제공됨, 이후 null
    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: hashedNonce,
    );

    final idToken = appleCredential.identityToken;
    if (idToken == null || idToken.isEmpty) {
      throw StateError(
        'Apple identityToken이 비어 있습니다. Xcode의 Sign in with Apple '
        'capability와 Firebase Apple 로그인 설정을 확인하세요.',
      );
    }

    final oauthCredential = OAuthProvider('apple.com').credential(
      idToken: idToken,
      rawNonce: rawNonce,
    );
    return (appleCredential, oauthCredential);
  }

  /// Firebase displayName이 비어 있고 Apple이 이름을 준 경우에만 저장.
  /// 이름 저장 실패가 로그인 실패로 번지지 않도록 예외는 삼킨다.
  Future<void> _saveAppleDisplayNameIfNeeded(
    User user,
    AuthorizationCredentialAppleID appleCredential,
  ) async {
    final current = user.displayName;
    if (current != null && current.isNotEmpty) return;

    // 한국어 이름 관례(성+이름)와 무관하게 Apple이 준 순서대로 조합
    final name = [appleCredential.givenName, appleCredential.familyName]
        .whereType<String>()
        .where((part) => part.trim().isNotEmpty)
        .join(' ')
        .trim();
    if (name.isEmpty) return;

    try {
      await user.updateDisplayName(name);
    } catch (e) {
      debugPrint('[Auth] displayName 저장 실패(무시): $e');
    }
  }

  // ── 회원 탈퇴 ────────────────────────────────────────────────────────────────

  /// 탈퇴 1단계: 재인증 (Firebase는 계정 삭제 전 최근 로그인 이력을 요구)
  /// Apple 계정이면 토큰 취소(revoke)에 필요한 authorizationCode를 반환한다.
  /// authorizationCode는 발급 후 5분만 유효하므로 탈퇴 직전에 새로 받아야 한다.
  Future<String?> reauthenticateForDelete() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('로그인된 사용자가 없습니다.');
    }

    final isAppleUser =
        user.providerData.any((p) => p.providerId == 'apple.com');

    if (isAppleUser) {
      final (appleCredential, oauthCredential) =
          await _getAppleOAuthCredential();
      await user.reauthenticateWithCredential(oauthCredential);
      return appleCredential.authorizationCode;
    }

    // Google 계정 재인증
    await _ensureInitialized();
    final googleUser = await _googleSignIn.authenticate();
    final idToken = googleUser.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw StateError('Google idToken이 비어 있습니다.');
    }
    await user.reauthenticateWithCredential(
      GoogleAuthProvider.credential(idToken: idToken),
    );
    return null;
  }

  /// 탈퇴 마지막 단계: (Apple) 토큰 취소 → Auth 계정 삭제 → 로컬 세션 정리
  /// 반드시 재인증·사용자 데이터 삭제가 끝난 뒤 호출해야 한다.
  /// (계정 삭제 후에는 Firestore 보안 규칙 때문에 데이터에 접근할 수 없음)
  Future<void> deleteAuthUser({String? appleAuthorizationCode}) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('로그인된 사용자가 없습니다.');
    }

    // Apple 심사 요건: 탈퇴 시 Sign in with Apple 토큰 취소
    // 취소 실패가 탈퇴 자체를 막지 않도록 로그만 남긴다
    if (appleAuthorizationCode != null) {
      try {
        await _auth.revokeTokenWithAuthorizationCode(appleAuthorizationCode);
      } catch (e) {
        debugPrint('[Auth] Apple 토큰 revoke 실패(무시): $e');
      }
    }

    await user.delete();

    // Google 로그인 세션 잔여물 정리 (Apple 사용자·미설정 환경에서는 실패해도 무시)
    try {
      await _ensureInitialized();
      await _googleSignIn.signOut();
    } catch (_) {}
  }

  // ── nonce 헬퍼 ──────────────────────────────────────────────────────────────

  /// 32바이트 랜덤 문자열 생성 (URL-safe 문자만 사용)
  String _generateNonce([int length = 32]) {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._';
    final random = Random.secure();
    return List.generate(length, (_) => chars[random.nextInt(chars.length)])
        .join();
  }

  /// 문자열을 SHA-256으로 해싱 후 16진수 문자열로 반환
  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}
