import 'package:plantapp_p/Data/models/gallery_photo_dto.dart';
import 'package:plantapp_p/domain/entities/gallery_photo.dart';

/// GalleryPhoto DTO ↔ Domain Entity 변환
// 도메인 영역은 외부 환경 (Firebase,서버)의 변화에 영향을 받으면 안된다

class GalleryPhotoMapper {
  //앱의 순수한 비지니스 규칙 모델(도메인 레이어,바뀌면 안됨)
  //Firebase로 부터 받은 DTO 객체를 Entity로 변환 (수신)
  static GalleryPhoto toEntity(GalleryPhotoDto dto) => GalleryPhoto(
        id: dto.id,
        photoUrl: dto.photoUrl,
        takenAt: dto.takenAt,
        memo: dto.memo,
      );

  //Firebase 의 규격에 맞춰진 모델 (데이터 레이어)
  //앱 내부에서 사용하던 Entity 객체를 서버가 이해할 수 있는 DTO형식으로 변환(송신)
  static GalleryPhotoDto toDto(GalleryPhoto entity) => GalleryPhotoDto(
        id: entity.id,
        photoUrl: entity.photoUrl,
        takenAt: entity.takenAt,
        memo: entity.memo,
      );
}
