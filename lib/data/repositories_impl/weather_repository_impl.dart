import 'package:plantapp_p/core/result/result.dart';
import 'package:plantapp_p/data/datasources/weather_remote_datasource.dart';
import 'package:plantapp_p/domain/entities/weather_forecast.dart';
import 'package:plantapp_p/domain/repositories/weather_repository.dart';

class WeatherRepositoryImpl implements WeatherRepository {
  final WeatherRemoteDataSource _dataSource;

  const WeatherRepositoryImpl(this._dataSource);

  @override
  Future<Result<WeatherForecast>> getForecast({
    required double lat,
    required double lon,
    required RecommendationSlot slot,
  }) =>
      _dataSource.getForecast(lat: lat, lon: lon, slot: slot);
}
