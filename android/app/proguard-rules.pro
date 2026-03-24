# Flutter 엔진 관련 난독화 제외
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# 안드로이드 기본 라이브러리 보호
-keep class androidx.lifecycle.** { *; }
-keep enum androidx.lifecycle.** { *; }

# JNI(자바-네이티브 인터페이스) 관련 오류 방지
-dontwarn io.flutter.embedding.**

# 만약 특정 패키지에서 에러가 난다면 해당 패키지를 dontwarn 처리
-dontwarn com.google.android.gms.**

# 알림 및 알람 라이브러리 보호
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keep class com.baseflow.permissionhandler.** { *; }