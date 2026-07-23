import 'package:plantapp_p/core/result/result.dart';
import 'package:plantapp_p/domain/entities/gallery_photo.dart';
import 'package:plantapp_p/domain/repositories/plant_repository.dart';

class GetGalleryPhotosUseCase {
  GetGalleryPhotosUseCase(this._repository);
  final PlantRepository _repository;

  Future<Result<List<GalleryPhoto>>> call(String plantId) =>
      _repository.getGalleryPhotos(plantId);
}
