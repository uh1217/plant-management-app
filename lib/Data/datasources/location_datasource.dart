import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:plantapp_p/core/result/result.dart';

/// GPS 위치 취득 데이터 소스
///
/// - `geolocator` 패키지를 래핑한다.
/// - 결과를 30분 메모리 캐시해 홈 화면 재진입 시 GPS 재요청을 방지한다.
/// - 권한 거부 시 `Failure`를 반환한다 (예외를 던지지 않음).
class LocationDataSource {
  static const _cacheTtl = Duration(minutes: 30);

  ({double lat, double lon})? _cachedPos;
  DateTime? _cachedAt;

  bool get _isCacheValid =>
      _cachedPos != null &&
      _cachedAt != null &&
      DateTime.now().difference(_cachedAt!) < _cacheTtl;

  Future<Result<({double lat, double lon})>> getCurrentPosition() async {
    if (_isCacheValid) {
      debugPrint('[LocationDataSource] 캐시 사용 (GPS 재요청 생략)');
      return Success(_cachedPos!);
    }

    try {
      // 위치 서비스 활성화 확인
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return const Failure(error: 'service_disabled', message: '위치 서비스가 비활성화되어 있습니다. 기기 설정에서 위치를 활성화해주세요.');
      }

      // 권한 확인 및 요청
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return const Failure(error: 'permission_denied', message: '위치 권한이 거부되었습니다.');
        }
      }
      if (permission == LocationPermission.deniedForever) {
        return const Failure(error: 'permission_denied_forever', message: '위치 권한이 영구적으로 거부되었습니다. 앱 설정에서 위치 권한을 허용해주세요.');
      }

      // 위치 취득 (도시 단위 날씨 조회에 충분한 reduced 정확도)
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.reduced,
          timeLimit: Duration(seconds: 10),
        ),
      );

      _cachedPos = (lat: position.latitude, lon: position.longitude);
      _cachedAt = DateTime.now();
      debugPrint(
          '[LocationDataSource] GPS 취득: lat=${position.latitude}, lon=${position.longitude}');
      return Success(_cachedPos!);
    } catch (e) {
      debugPrint('[LocationDataSource] GPS 오류: $e');
      return Failure(error: e, message: '위치 정보를 가져올 수 없습니다.');
    }
  }

  /// 캐시 강제 무효화 (테스트 또는 설정 변경 시 사용)
  void invalidateCache() {
    _cachedPos = null;
    _cachedAt = null;
  }
}
