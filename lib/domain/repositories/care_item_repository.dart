import 'package:plantapp_p/core/result/result.dart';
import 'package:plantapp_p/domain/entities/care_item.dart';

/// 케어 버튼(비료/농약) 데이터 접근 설계도
abstract class CareItemRepository {
  Future<Result<List<CareItem>>> getCareItems();

  /// 등록 성공 시 생성된 ID가 채워진 CareItem 반환
  Future<Result<CareItem>> addCareItem(CareItem item);

  Future<Result<void>> deleteCareItem(String itemId);
}
