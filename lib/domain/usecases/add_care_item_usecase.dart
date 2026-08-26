import 'package:plantapp_p/core/result/result.dart';
import 'package:plantapp_p/domain/entities/care_item.dart';
import 'package:plantapp_p/domain/repositories/care_item_repository.dart';

/// 케어 버튼 등록 유스케이스 — 성공 시 생성된 ID가 채워진 CareItem 반환
class AddCareItemUseCase {
  AddCareItemUseCase(this._repository);
  final CareItemRepository _repository;

  Future<Result<CareItem>> call(CareItem item) =>
      _repository.addCareItem(item);
}
