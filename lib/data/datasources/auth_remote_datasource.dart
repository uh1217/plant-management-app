import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

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
    await _ensureInitialized();
    // disconnect는 계정 연결 해제로 재동의 팝업을 유발할 수 있어 signOut만 사용
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}
