import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:plantapp_p/core/result/result.dart';

/// 사용자가 선택한 도시의 좌표를 SharedPreferences에 저장·조회하는 데이터 소스
///
/// GPS 권한 없이 사전 정의된 한국 주요 도시 목록에서 도시를 선택해 사용한다.
class CityDataSource {
  static const _prefKey = 'selected_city_name';

  /// 한국 주요 도시 목록 (도시명 → lat/lon)
  static const Map<String, ({double lat, double lon})> cities = {
    '서울': (lat: 37.5665, lon: 126.9780),
    '부산': (lat: 35.1796, lon: 129.0756),
    '대구': (lat: 35.8714, lon: 128.6014),
    '인천': (lat: 37.4563, lon: 126.7052),
    '광주': (lat: 35.1595, lon: 126.8526),
    '대전': (lat: 36.3504, lon: 127.3845),
    '울산': (lat: 35.5384, lon: 129.3114),
    '세종': (lat: 36.4800, lon: 127.2890),
    '수원': (lat: 37.2636, lon: 127.0286),
    '청주': (lat: 36.6424, lon: 127.4890),
    '전주': (lat: 35.8242, lon: 127.1480),
    '창원': (lat: 35.2279, lon: 128.6811),
    '포항': (lat: 36.0190, lon: 129.3435),
    '천안': (lat: 36.8151, lon: 127.1139),
    '강릉': (lat: 37.7519, lon: 128.8761),
    '춘천': (lat: 37.8813, lon: 127.7298),
    '안산': (lat: 37.3219, lon: 126.8309),
    '제주': (lat: 33.4996, lon: 126.5312),
  };

  /// SharedPreferences에 저장된 도시명 반환. 미선택이면 null.
  Future<String?> getSelectedCityName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefKey);
  }

  /// 선택된 도시명을 SharedPreferences에 저장
  Future<void> saveCity(String cityName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, cityName);
    debugPrint('[CityDataSource] 도시 저장: $cityName');
  }

  /// 저장된 도시의 lat/lon 반환.
  /// 미선택이면 no_city_selected Failure, 목록에 없는 도시면 city_not_found Failure.
  Future<Result<({double lat, double lon})>> getPosition() async {
    final cityName = await getSelectedCityName();
    if (cityName == null || cityName.isEmpty) {
      return const Failure(
        error: 'no_city_selected',
        message: '도시가 선택되지 않았습니다. 날씨 추천 설정에서 도시를 선택해주세요.',
      );
    }
    final pos = cities[cityName];
    if (pos == null) {
      return Failure(
        error: 'city_not_found',
        message: '선택된 도시($cityName)를 목록에서 찾을 수 없습니다.',
      );
    }
    debugPrint('[CityDataSource] 도시 위치 사용: $cityName (${pos.lat}, ${pos.lon})');
    return Success(pos);
  }
}
