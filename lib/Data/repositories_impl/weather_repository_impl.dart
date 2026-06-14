import 'package:plantapp_p/core/result/result.dart';
import 'package:plantapp_p/Data/datasources/weather_remote_datasource.dart';
import 'package:plantapp_p/Domain/entities/weather_forecast.dart';
import 'package:plantapp_p/Domain/repositories/weather_repository.dart';

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
