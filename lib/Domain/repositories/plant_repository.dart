import 'package:plantapp_p/core/result/result.dart';
import 'package:plantapp_p/domain/entities/gallery_photo.dart';
import 'package:plantapp_p/domain/entities/plant.dart';

/// 식물·갤러리 데이터 접근 설계도 (기능 구현 X)
// -> 외역 레이어가 내부 레이어를 바라보게 의존성의 방향이 역전되어 고도로 유연한 독립성을 얻음
abstract class PlantRepository {
  Future<Result<List<Plant>>> getPlants();
  Future<Result<void>> savePlant(Plant plant);
  Future<Result<void>> deletePlant(String plantId);
  Future<Result<void>> waterPlant(String plantId, String isoDate);
  Future<Result<void>> fertilizePlant(String plantId, String isoDate);
  Future<Result<List<GalleryPhoto>>> getGalleryPhotos(String plantId);
  Future<Result<void>> addGalleryPhoto(String plantId, GalleryPhoto photo);
}
