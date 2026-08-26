import 'package:plantapp_p/core/result/result.dart';
import 'package:plantapp_p/domain/repositories/care_item_repository.dart';

/// 케어 버튼 삭제 유스케이스 — 버튼만 삭제, 식물별 기록(스냅샷)은 유지
class DeleteCareItemUseCase {
  DeleteCareItemUseCase(this._repository);
  final CareItemRepository _repository;

  Future<Result<void>> call(String itemId) =>
      _repository.deleteCareItem(itemId);
}
