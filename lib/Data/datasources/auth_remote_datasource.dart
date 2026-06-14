import 'package:firebase_auth/firebase_auth.dart';
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

  //Stream : 데이터가 흐르는 파이프라인 (유저가 로그인/로그아웃 시 파이어베이스가 실시간으로 상태 보내줌)
  Stream<String?> get authStateChanges =>
      _auth.authStateChanges().map((user) => user?.uid); //map을 활용해 uid만 전달

  Future<String> signInWithGoogle() async {
    await _googleSignIn.initialize(); // 구글 SDK 초기화
    //유저가 구글 계정 선택 창을 띄우고 취소하면 에러를 던져 흐름 끊음
    final googleUser = await _googleSignIn.authenticate(); // 계정 선택 팝업 표시
    if (googleUser == null) {
      throw StateError('Google sign-in cancelled');
    }

    // 구글이 허용하면 파이어베이스가 알 수 있는 입장권으로 바꿈
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
    );
    //그 입장권으로 파이베이스 서버에 로그인하고, 최종 성공하면 유저 고유 아이디 (uid) 반환
    final userCredential = await _auth.signInWithCredential(credential); // 입장권으로 Firebase 로그인
    final uid = userCredential.user?.uid;
    if (uid == null) {
      throw StateError('Firebase user is null after sign-in');
    }
    return uid;
  }

  //파이어베이스 뿐 아니라 구글 로그인 세션까지 완전히 연결 끊어버림
  Future<void> signOut() async {
    await _googleSignIn.disconnect();
    await _auth.signOut();
  }
}
