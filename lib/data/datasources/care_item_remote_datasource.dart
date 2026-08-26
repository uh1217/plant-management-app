import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:plantapp_p/data/models/care_item_dto.dart';

/// Firestore care_items(케어 버튼) 원격 데이터 소스
/// 경로: users/{uid}/care_items/{item_id}
class CareItemRemoteDataSource {
  CareItemRemoteDataSource({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  // 기본 버튼("비료"/"농약") 생성 여부 플래그 — 사용자가 모든 버튼을 지워도 재생성되지 않도록 별도 저장
  static const _defaultsFlagField = 'care_defaults_created';

  // 기본 버튼 색: 기존 툴바 아이콘 색과 동일 (AppColors.primaryGreen / yellow200)
  static const _defaultFertilizerColor = 0xFF22C55E;
  static const _defaultPesticideColor = 0xFFF9D48A;

  DocumentReference<Map<String, dynamic>> _userDoc() {
    final uid = _auth.currentUser!.uid;
    return _db.collection('users').doc(uid);
  }

  CollectionReference<Map<String, dynamic>> _itemsCol() {
    return _userDoc().collection('care_items');
  }

  /// 버튼 목록 조회 — 최초 1회 기본 버튼 자동 생성 후 생성 순서로 반환
  Future<List<CareItemDto>> getCareItems() async {
    await _ensureDefaultItems();
    final snapshot = await _itemsCol().orderBy('created_at').get();
    return snapshot.docs
        .map((d) => CareItemDto.fromFirestore(d.data(), d.id))
        .toList();
  }

  Future<void> _ensureDefaultItems() async {
    final userSnap = await _userDoc().get();
    if (userSnap.data()?[_defaultsFlagField] == true) return;

    // 고정 ID 사용: 여러 기기가 동시에 최초 실행되어도 중복 생성 대신 덮어쓰기 (멱등)
    final now = DateTime.now().toIso8601String();
    final batch = _db.batch();
    batch.set(_itemsCol().doc('default_fertilizer'), {
      'type': 'fertilizer',
      'name': '비료',
      'color': _defaultFertilizerColor,
      'cycle_memo': '',
      'include_watering': true,
      'created_at': now,
    });
    batch.set(_itemsCol().doc('default_pesticide'), {
      'type': 'pesticide',
      'name': '농약',
      'color': _defaultPesticideColor,
      'cycle_memo': '',
      'include_watering': true,
      'created_at': now,
    });
    batch.set(_userDoc(), {_defaultsFlagField: true}, SetOptions(merge: true));
    await batch.commit();
  }

  /// 새 버튼 등록 후 생성된 ID를 포함한 DTO 반환
  Future<CareItemDto> addCareItem(CareItemDto item) async {
    final docRef = _itemsCol().doc();
    await docRef.set(item.toFirestore());
    return CareItemDto(
      id: docRef.id,
      type: item.type,
      name: item.name,
      color: item.color,
      cycleMemo: item.cycleMemo,
      includeWatering: item.includeWatering,
      createdAt: item.createdAt,
    );
  }

  /// 버튼 문서만 삭제 — 각 식물의 기록(스냅샷)은 그대로 유지됨
  Future<void> deleteCareItem(String itemId) async {
    await _itemsCol().doc(itemId).delete();
  }
}
