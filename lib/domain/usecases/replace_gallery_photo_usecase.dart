import 'package:plantapp_p/core/result/result.dart';
import 'package:plantapp_p/domain/entities/gallery_photo.dart';
import 'package:plantapp_p/domain/repositories/plant_repository.dart';

class ReplaceGalleryPhotoUseCase {
  ReplaceGalleryPhotoUseCase(this._repository);
  final PlantRepository _repository;

  Future<Result<void>> call(
    String plantId,
    GalleryPhoto photo,
    String previousPhotoUrl,
  ) =>
      _repository.replaceGalleryPhoto(plantId, photo, previousPhotoUrl);
}
