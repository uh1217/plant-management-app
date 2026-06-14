import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'package:plantapp_p/Data/models/gallery_photo_dto.dart';
import 'package:plantapp_p/Data/models/plant_dto.dart';

/// Firestore plants / gallery 원격 데이터 소스 -> firestore에 저장하고 관리
class PlantRemoteDataSource {
  PlantRemoteDataSource({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _db = firestore ?? FirebaseFirestore.instance, //테스트용 서버 사용 대비
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  
  //uid를 통해 plants 폴더 주소 반환(사용자가 무조건 로그인 되있다고 가정)
  CollectionReference<Map<String, dynamic>> _plantsCol() {
    final uid = _auth.currentUser!.uid;
    return _db.collection('users').doc(uid).collection('plants');
  }

  //특정 식물 안에 갤러리 폴더를 하나 더 팜
  CollectionReference<Map<String, dynamic>> _galleryCol(String plantId) {
    return _plantsCol().doc(plantId).collection('gallery');
  }

  //서버로 보내기 위해 DTO객체 사용
  Future<void> savePlant(PlantDto plant) async {
    await _plantsCol().doc(plant.id).set(plant.toFirestore());
    //                  파일 지정     데이터 덮어쓰기(JSON 변환)
  }

  Future<List<PlantDto>> getAllPlants() async {
    final snapshot = await _plantsCol().get(); //get()을 통해 _plantsCol에 있는 파일 다 긁어옴
    return snapshot.docs
        .map((d) => PlantDto.fromFirestore(d.data(), d.id)) //JSON 데이터 DTO형태로 바꿔 List 형태로 포장
        .toList();
  }

  //WriteBatch 를 이용해 plant 객체만 지워지는게 아닌 하위의 gallery도 지움
  Future<void> deletePlant(String plantId) async {
    // Storage에 업로드된 대표 이미지 삭제 시도
    try {
      final doc = await _plantsCol().doc(plantId).get();
      final imageUrl = doc.data()?['image_url'] as String?;
      if (imageUrl != null && imageUrl.startsWith('https://firebasestorage')) {
        await FirebaseStorage.instance.refFromURL(imageUrl).delete();
      }
    } catch (_) {}

    // gallery 서브컬렉션의 Storage 이미지를 병렬로 삭제 시도
    final gallery = await _galleryCol(plantId).get();
    await Future.wait(
      gallery.docs.map((doc) async {
        try {
          final photoUrl = doc.data()['photo_url'] as String?;
          if (photoUrl != null &&
              photoUrl.startsWith('https://firebasestorage')) {
            await FirebaseStorage.instance.refFromURL(photoUrl).delete();
          }
        } catch (_) {}
      }),
    );

    final batch = _db.batch();
    for (final doc in gallery.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(_plantsCol().doc(plantId));
    await batch.commit();
  }

  //Firestore의 기능인 FieldValue.arrayUnion 를 사용해 배열의 맨뒤에 날짜 추가
  Future<void> waterPlant(String plantId, String date) async {
    await _plantsCol().doc(plantId).update({
      'last_watered': date,
      'watering_history': FieldValue.arrayUnion([date]),
    });
  }

  Future<void> fertilizePlant(String plantId, String date) async {
    await _plantsCol().doc(plantId).update({
      'fertilizer_history': FieldValue.arrayUnion([date]),
    });
  }

  Future<void> addGalleryPhoto(String plantId, GalleryPhotoDto photo) async {
    await _galleryCol(plantId).doc(photo.id).set(photo.toFirestore());
  }


  //갤러리를 조회할 때 날짜 순으로 정렬
  Future<List<GalleryPhotoDto>> getGalleryPhotos(String plantId) async {
    final snapshot = await _galleryCol(plantId)
        .orderBy('taken_at', descending: true)
        .get();
    return snapshot.docs
        .map((d) => GalleryPhotoDto.fromFirestore(d.data(), d.id))
        .toList();
  }
}
