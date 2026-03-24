//앱 실행, 전체 테마 설정, home_screen으로 라우팅
import 'package:flutter/material.dart';
import 'presentation/home_screen.dart';
import 'presentation/app_theme.dart';
//import 'presentation/alarm.dart';



void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  //await AlarmService.init();
  await AppTheme.loadTheme();
  runApp(const PlantManagerApp()); //첫 동작
}

class PlantManagerApp extends StatelessWidget {
  const PlantManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 💡 방송국(themeNotifier)의 값이 바뀔 때마다 아래 builder가 다시 실행됩니다!
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppTheme.themeNotifier,
      builder: (context, ThemeMode currentMode, child) {
        return MaterialApp(
          title: 'Plant App',
          theme: AppTheme.lightTheme,      // ☀️ 라이트 테마
          darkTheme: AppTheme.darkTheme,   // 🌙 다크 테마
          themeMode: currentMode,          // 👈 방송국에서 알려준 현재 모드 적용!
          home: const HomeScreen(),
        );
      },
    );
  }
}
