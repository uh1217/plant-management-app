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

# Google Play Services / Credential Manager (릴리스 minify 시 로그인 깨짐 방지)
-keep class com.google.android.gms.** { *; }
-keep class com.google.android.libraries.identity.** { *; }
-keep class com.google.android.libraries.identity.googleid.** { *; }
-dontwarn com.google.android.gms.**
-dontwarn com.google.android.libraries.identity.**

# Firebase Auth
-keep class com.google.firebase.auth.** { *; }
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# 알림 및 알람 라이브러리 보호
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keep class com.baseflow.permissionhandler.** { *; }

# flutter_local_notifications가 내부적으로 쓰는 Gson의 제네릭 타입 정보 보호
# (R8이 Signature를 제거하면 알람 예약 시 "Missing type parameter" 크래시 발생)
-keepattributes Signature
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
