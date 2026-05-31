/// Firestore gallery 문서 DTO
class GalleryPhotoDto {
  final String id;
  final String photoUrl;
  final String takenAt;
  final String memo;

  const GalleryPhotoDto({
    required this.id,
    required this.photoUrl,
    required this.takenAt,
    required this.memo,
  });

  factory GalleryPhotoDto.fromFirestore(
    Map<String, dynamic> map,
    String documentId,
  ) {
    return GalleryPhotoDto(
      id: documentId,
      photoUrl: map['photo_url'] as String? ?? '',
      takenAt: map['taken_at'] as String? ?? '',
      memo: map['memo'] as String? ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'photo_url': photoUrl,
      'taken_at': takenAt,
      'memo': memo,
    };
  }
}
