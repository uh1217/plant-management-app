import 'package:plantapp_p/core/result/result.dart';
import 'package:plantapp_p/domain/entities/gallery_photo.dart';
import 'package:plantapp_p/domain/entities/plant.dart';
import 'package:plantapp_p/domain/repositories/plant_repository.dart';
import 'package:plantapp_p/Data/datasources/plant_remote_datasource.dart';
import 'package:plantapp_p/Data/mappers/gallery_photo_mapper.dart';
import 'package:plantapp_p/Data/mappers/plant_mapper.dart';

/// PlantRepository Firestore 구현체
class PlantRepositoryImpl implements PlantRepository {
  PlantRepositoryImpl(this._remote);
  final PlantRemoteDataSource _remote;

  //서버에서 데이터를 가져오는 PlantRemoteDataSource
  //가져온 데이터 도메인 양식으로 바꿔주는 Mapper (usecase에서 사용)
  @override
  Future<Result<List<Plant>>> getPlants() async {
    try {
      final dtos = await _remote.getAllPlants(); // 1. 원격 서버에서 DTO 리스트(날것) 수집
      return Success(dtos.map(PlantMapper.toEntity).toList()); // 2. 매퍼를 통해 순수 Entity 리스트로 둔갑시켜 반환
    } catch (e) {
      return Failure(error: e, message: '식물 목록을 불러오지 못했습니다.');
    }
  }

  @override
  Future<Result<void>> savePlant(Plant plant) async {
    try {
      // getPlants 와 반대로 동작
      await _remote.savePlant(PlantMapper.toDto(plant));
      return const Success(null);
    } catch (e) {
      return Failure(error: e, message: '식물 저장에 실패했습니다.');
    }
  }

  @override
  Future<Result<void>> deletePlant(String plantId) async {
    try {
      await _remote.deletePlant(plantId);
      return const Success(null);
    } catch (e) {
      return Failure(error: e, message: '식물 삭제에 실패했습니다.');
    }
  }

  @override
  Future<Result<void>> waterPlant(String plantId, String isoDate) async {
    try {
      await _remote.waterPlant(plantId, isoDate);
      return const Success(null);
    } catch (e) {
      return Failure(error: e, message: '물 주기 기록에 실패했습니다.');
    }
  }

  @override
  Future<Result<void>> fertilizePlant(String plantId, String isoDate) async {
    try {
      await _remote.fertilizePlant(plantId, isoDate);
      return const Success(null);
    } catch (e) {
      return Failure(error: e, message: '비료 주기 기록에 실패했습니다.');
    }
  }

  @override
  Future<Result<List<GalleryPhoto>>> getGalleryPhotos(String plantId) async {
    try {
      final dtos = await _remote.getGalleryPhotos(plantId);
      return Success(dtos.map(GalleryPhotoMapper.toEntity).toList());
    } catch (e) {
      return Failure(error: e, message: '갤러리를 불러오지 못했습니다.');
    }
  }

  @override
  Future<Result<void>> addGalleryPhoto(
    String plantId,
    GalleryPhoto photo,
  ) async {
    try {
      await _remote.addGalleryPhoto(
        plantId,
        GalleryPhotoMapper.toDto(photo),
      );
      return const Success(null);
    } catch (e) {
      return Failure(error: e, message: '사진 저장에 실패했습니다.');
    }
  }
}
