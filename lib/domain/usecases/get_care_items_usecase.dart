import 'package:plantapp_p/core/result/result.dart';
import 'package:plantapp_p/domain/entities/care_item.dart';
import 'package:plantapp_p/domain/repositories/care_item_repository.dart';

/// 케어 버튼 목록 조회 유스케이스 (최초 1회 기본 버튼 자동 생성 포함)
class GetCareItemsUseCase {
  GetCareItemsUseCase(this._repository);
  final CareItemRepository _repository;

  Future<Result<List<CareItem>>> call() => _repository.getCareItems();
}
