import 'package:flutter/foundation.dart';

import 'package:plantapp_p/core/result/result.dart';
import 'package:plantapp_p/data/datasources/care_item_remote_datasource.dart';
import 'package:plantapp_p/data/mappers/care_item_mapper.dart';
import 'package:plantapp_p/domain/entities/care_item.dart';
import 'package:plantapp_p/domain/repositories/care_item_repository.dart';

/// CareItemRepository Firestore 구현체
class CareItemRepositoryImpl implements CareItemRepository {
  CareItemRepositoryImpl(this._remote);
  final CareItemRemoteDataSource _remote;

  @override
  Future<Result<List<CareItem>>> getCareItems() async {
    try {
      final dtos = await _remote.getCareItems();
      return Success(dtos.map(CareItemMapper.toEntity).toList());
    } catch (e) {
      debugPrint('[CareItemRepository] getCareItems 실패: $e');
      return Failure(error: e, message: '케어 버튼 목록을 불러오지 못했습니다.');
    }
  }

  @override
  Future<Result<CareItem>> addCareItem(CareItem item) async {
    try {
      final created = await _remote.addCareItem(CareItemMapper.toDto(item));
      return Success(CareItemMapper.toEntity(created));
    } catch (e) {
      debugPrint('[CareItemRepository] addCareItem 실패: $e');
      return Failure(error: e, message: '버튼 등록에 실패했습니다.');
    }
  }

  @override
  Future<Result<void>> deleteCareItem(String itemId) async {
    try {
      await _remote.deleteCareItem(itemId);
      return const Success(null);
    } catch (e) {
      debugPrint('[CareItemRepository] deleteCareItem 실패: $e');
      return Failure(error: e, message: '버튼 삭제에 실패했습니다.');
    }
  }
}
