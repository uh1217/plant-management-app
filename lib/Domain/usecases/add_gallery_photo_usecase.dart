import 'package:plantapp_p/core/result/result.dart';
import 'package:plantapp_p/domain/entities/gallery_photo.dart';
import 'package:plantapp_p/domain/repositories/plant_repository.dart';

class AddGalleryPhotoUseCase {
  AddGalleryPhotoUseCase(this._repository);
  final PlantRepository _repository;

  Future<Result<void>> call(String plantId, GalleryPhoto photo) =>
      _repository.addGalleryPhoto(plantId, photo);
}
