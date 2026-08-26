import 'package:package_info_plus/package_info_plus.dart';

/// pubspec `version:`(빌드된 versionName)을 UI 표시용으로 보관한다.
/// main()에서 init()을 한 번 호출한 뒤 [label]을 쓴다.
class AppVersion {
  AppVersion._();
  static final AppVersion instance = AppVersion._();

  /// 예: `Version 2.4.6`
  String label = 'Version';

  Future<void> init() async {
    final info = await PackageInfo.fromPlatform();
    final version = info.version.trim();
    label = version.isEmpty ? 'Version' : 'Version $version';
  }
}
