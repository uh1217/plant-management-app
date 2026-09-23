import 'package:plantapp_p/core/result/result.dart';
import 'package:plantapp_p/domain/repositories/plant_repository.dart';

class DeleteGalleryPhotoUseCase {
  DeleteGalleryPhotoUseCase(this._repository);
  final PlantRepository _repository;

  Future<Result<void>> call(
    String plantId,
    String photoId,
    String photoUrl,
  ) =>
      _repository.deleteGalleryPhoto(plantId, photoId, photoUrl);
}
