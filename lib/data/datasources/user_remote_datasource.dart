import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

/// 회원 탈퇴 시 사용자 데이터 전체 삭제를 담당하는 원격 데이터 소스
///
/// 삭제 대상 (db_schema.md 참고):
/// - Storage:   users/{uid}/ 폴더 전체 (식물 대표 사진 + 갤러리 사진)
/// - Firestore: users/{uid} 문서와 하위 plants(+gallery), care_items 서브컬렉션
///
/// 주의: Firebase Auth 계정 삭제(user.delete()) "이전"에 호출해야 한다.
/// 계정이 먼저 삭제되면 보안 규칙 때문에 데이터 접근이 거부된다.
class UserRemoteDataSource {
  UserRemoteDataSource({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    FirebaseStorage? storage,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final FirebaseStorage _storage;

  Future<void> deleteAllUserData() async {
    final uid = _auth.currentUser!.uid;
    final userDoc = _db.collection('users').doc(uid);

    // 1. Storage 먼저 삭제 — Firestore 문서가 먼저 지워지면
    //    이미지 URL을 잃어도 폴더 경로(users/{uid})로는 지울 수 있지만,
    //    도중 실패 시 재시도 관점에서 Storage → Firestore 순서가 안전하다
    await _deleteStorageFolder(_storage.ref().child('users/$uid'));

    // 2. Firestore: 서브컬렉션은 부모 문서 삭제로 지워지지 않으므로 직접 순회
    final plants = await userDoc.collection('plants').get();
    for (final plant in plants.docs) {
      final gallery = await plant.reference.collection('gallery').get();
      final batch = _db.batch();
      for (final photo in gallery.docs) {
        batch.delete(photo.reference);
      }
      batch.delete(plant.reference);
      await batch.commit();
    }

    final careItems = await userDoc.collection('care_items').get();
    final batch = _db.batch();
    for (final item in careItems.docs) {
      batch.delete(item.reference);
    }
    batch.delete(userDoc);
    await batch.commit();
  }

  /// Storage 폴더를 재귀적으로 비운다.
  /// 개별 파일 삭제 실패(이미 없는 파일 등)는 탈퇴를 막지 않도록 무시한다.
  Future<void> _deleteStorageFolder(Reference folder) async {
    final ListResult result = await folder.listAll();

    await Future.wait(result.items.map((file) async {
      try {
        await file.delete();
      } catch (e) {
        debugPrint('[User] Storage 파일 삭제 실패(무시): ${file.fullPath} $e');
      }
    }));

    for (final subFolder in result.prefixes) {
      await _deleteStorageFolder(subFolder);
    }
  }
}
