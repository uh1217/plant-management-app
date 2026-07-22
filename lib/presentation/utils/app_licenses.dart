import 'package:flutter/foundation.dart';

/// pub 패키지 외 앱 자체 에셋·서비스 출처를 LicensePage에 추가한다.
/// Flutter·Firebase 등 OSS 라이선스는 빌드 시 자동 수집되므로 여기에 적지 않는다.
void registerAppLicenses() {
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(
      ['이미지 에셋'],
      '배경·플레이스홀더 이미지: Designed by Freepik\n'
      'https://www.freepik.com',
    );
  });
}
