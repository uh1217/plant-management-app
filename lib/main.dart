//앱 실행, 전체 테마 설정, home_screen으로 라우팅
import 'package:flutter/material.dart';
import 'presentation/views/home_screen.dart';
import 'presentation/app_theme.dart';
import 'presentation/views/login_screen.dart';
import 'package:plantapp_p/core/services/notification_service.dart';

// 파이어베이스 본체 (Firebase.initializeApp을 인식하게 해줌)
import 'package:firebase_core/firebase_core.dart'; 
// 파이어베이스 설정 파일 (DefaultFirebaseOptions를 인식하게 해줌)
import 'firebase_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:plantapp_p/core/di/service_locator.dart';
import 'package:plantapp_p/presentation/viewmodels/home_view_model.dart';  
import 'package:plantapp_p/presentation/viewmodels/login_view_model.dart';
import 'package:plantapp_p/presentation/utils/app_licenses.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); //비동기 작업 렌더링 준비
  registerAppLicenses();
  // 알림 채널 초기화 및 알림 권한 요청 (Firebase보다 먼저 실행)
  await NotificationService.instance.init();
  await Firebase.initializeApp( //firebase 와 앱 연결 (Firebase SDK 초기화)
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // 오프라인 퍼시스턴스: 로컬 디스크에 Firestore 데이터를 캐시해
  // 앱 재시작 시 네트워크 없이도 즉시 데이터를 표시하고, 백그라운드에서 동기화함.
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );
  // TODO(보안): 프로덕션 배포 전 App Check를 반드시 활성화할 것.
  // App Check가 꺼져 있으면 firebase_options.dart를 얻은 누구나
  // 이 프로젝트의 Gemini 쿼터를 무단 소비할 수 있음.
  // 활성화 시 Firebase Console > App Check > Android > Play Integrity 등록 필요.
  /*await FirebaseAppCheck.instance.activate(
    androidProvider: kReleaseMode
        ? AndroidProvider.playIntegrity
        : AndroidProvider.debug,
  );*/

  ServiceLocator.instance.init(); //init 동작 시점 먼저 나와야 함
  await AppTheme.loadTheme();
  runApp(const PlantManagerApp()); //첫 동작
}

class PlantManagerApp extends StatelessWidget {
  const PlantManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppThemeType>(
      valueListenable: AppTheme.themeNotifier,
      builder: (context, AppThemeType currentTheme, child) {
        return MaterialApp(
          title: 'Plant App',
          theme: AppTheme.getTheme(currentTheme),
          themeMode: ThemeMode.light,
          home: const _AuthGate(),
        );
      },
    );
  }
}

// _AuthGate: 로그인 상태를 감지해 화면을 분기하는 게이트 위젯
// StatefulWidget으로 선언하는 이유:
//   StreamBuilder가 Firebase 이벤트를 받을 때마다 builder를 재실행하는데,
//   StatelessWidget이면 그때마다 createHomeViewModel()이 새로 호출된다.
//   → ViewModel 인스턴스가 계속 교체되어 리스너가 고아 상태가 되는 버그 발생.
//   → StatefulWidget의 initState에서 딱 한 번만 생성해 재사용한다.
class _AuthGate extends StatefulWidget {
  const _AuthGate();
  @override
  State<_AuthGate> createState() => _AuthGateState();
}
class _AuthGateState extends State<_AuthGate> {
  late final HomeViewModel _homeViewModel;
  late final LoginViewModel _loginViewModel;
  @override
  void initState() {
    super.initState();
    // ServiceLocator가 이미 init()된 상태이므로
    // 여기서 안전하게 ViewModel을 생성할 수 있다
    _homeViewModel  = ServiceLocator.instance.createHomeViewModel();
    _loginViewModel = ServiceLocator.instance.createLoginViewModel();
  }
  @override
  void dispose() {
    _homeViewModel.dispose();   // 앱 종료 시 리스너 정리
    _loginViewModel.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(), // 로그인 상태 실시간 감지
      builder: (context, snapshot) {
        // 1. Firebase 연결 대기 중 (FirebaseAuth가 로컬 캐시에서 세션 토큰 발견 → authStateChanges() 스트림이 User(non-null) 방출))
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        // 2. 로그인 O → 홈 화면 (ViewModel 주입)
        if (snapshot.hasData) {
          return HomeScreen(viewModel: _homeViewModel);
        }
        // 3. 로그인 X → 로그인 화면 (ViewModel 주입) -> 이 경우 로그인 로직 실행행
        return LoginScreen(viewModel: _loginViewModel);
      },
    );
  }
}