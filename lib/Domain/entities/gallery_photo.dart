/// 갤러리 사진 도메인 엔티티
class GalleryPhoto {
  final String id;
  final String photoUrl;
  final String takenAt;
  final String memo;

  const GalleryPhoto({
    required this.id,
    required this.photoUrl,
    required this.takenAt,
    required this.memo,
  });

  String get formattedDate {
    if (takenAt.isEmpty) return '';
    try {
      final date = DateTime.parse(takenAt);
      return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return takenAt;
    }
  }
}
