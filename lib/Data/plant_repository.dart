// lib/Data/plant_repository.dart (파일 분리 추천)
import '../models/plant.dart';
import '../Data/data.dart'; // AppDatabase가 정의된 파일



class PlantRepository {
PlantRepository._privateConstructor(); // 내부 생성자
  static final PlantRepository instance = PlantRepository._privateConstructor();

  // 저장 
  Future<void> insertPlant(Plant plant) async {//실제 가공된 값 db에 저장
    try {
      final db = await AppDatabase.instance.database;
      // 트랜잭션: 여러 테이블 작업 중 하나라도 실패하면 모두 취소(Rollback)함 -> 식물 이름,사진등만 저장되고 카테고리 저정전 종료 방지
      await db.transaction((txn) async {//transaction이나 txn모두 sqlite 내장 기능
        // 식물 기본 정보 저장(*핵심*)
        await txn.insert('plants', plant.toMap());

        // 카테고리 연결 로직 
        for (var categoryName in plant.categories) {
          //카테고리 기존에 있는지 확인
          final List<Map<String, dynamic>> existingCats = await txn.query(
            'categories', where: 'name = ?', whereArgs: [categoryName],
          );

          int categoryId = existingCats.isEmpty 
          //없으면 추가
              ? await txn.insert('categories', {'name': categoryName}) 
          //있으면 기존 ID가져오기
              : existingCats.first['id'];

          await txn.insert('plant_categories', {'plant_id': plant.id, 'category_id': categoryId});
        }

        // 물 주기 이력 저장
        for (var date in plant.wateringHistory) {
          await txn.insert('watering_history', {'plant_id': plant.id, 'date': date});
        }
        // 비료 주기 이력 저장
        for (var date in plant.fertilizerHistory) {
          await txn.insert('fertilizer_history', {'plant_id': plant.id, 'date': date});
        }
      });
      } catch (e) {
        // 🚨 여기서 처리하지 않고 호출한 곳(UI)으로 던집니다!
        rethrow;
      }
  }
  
  Future<void> updatePlant(Plant plant) async {
  try {
    final db = await AppDatabase.instance.database;
    
    await db.transaction((txn) async {
      // 1. 식물 기본 정보 업데이트 (이름, 사진, 빈도, 메모 등) map에 들어가있는 정보 전부
      await txn.update(
        'plants',
        plant.toMap(),
        where: 'id = ?',
        whereArgs: [plant.id],
      );

      // ⚠️ 2. [매우 중요] 기존 '연결' 테이블 데이터 삭제
      // 수정창에서 카테고리를 삭제하거나 변경했을 수 있으므로, 
      // 기존 연결을 완전히 끊고 새로 받은 cleanCategories로 다시 연결해야 합니다.
      await txn.delete('plant_categories', where: 'plant_id = ?', whereArgs: [plant.id]);

      // 3. 카테고리 재연결 (수정창의 cleanCategories 반영)
      for (var categoryName in plant.categories) {
        // (기존 코드처럼 categories 테이블 확인 후 ID 가져오기/생성 로직 수행)
        final List<Map<String, dynamic>> existingCats = await txn.query(
          'categories', where: 'name = ?', whereArgs: [categoryName],
        );
        int categoryId = existingCats.isEmpty 
            ? await txn.insert('categories', {'name': categoryName}) 
            : existingCats.first['id'];

        await txn.insert('plant_categories', {
          'plant_id': plant.id, 
          'category_id': categoryId
        });
      }

      // 식물에 등록되지 않은 카테고리 목록 삭제
      await txn.rawDelete('''
        DELETE FROM categories 
        WHERE id NOT IN (SELECT DISTINCT category_id FROM plant_categories)
      ''');

      // 4. 이력(History) 데이터 처리
      // 수정창에서 이력을 직접 건드리지 않는다면 삭제 후 재삽입할 필요가 없지만,
      // 만약 '식물 정보 수정' 시 이력 유실이 걱정된다면 이 부분은 delete 없이 유지하는 것이 좋습니다.
      // (단, 이력 테이블을 초기화하고 다시 넣는 방식을 택했다면 중복 체크가 필요합니다.)
    });
  } catch (e) {
    rethrow;
  }

  
}

  // 2. 전체 조회 (홈 화면용)
  Future<List<Plant>> getAllPlants() async {
    final db = await AppDatabase.instance.database;
    final List<Map<String, dynamic>> plantMaps = await db.query('plants');

    List<Plant> plants = [];
    for (var map in plantMaps) {
      final plantId = map['id'];
      
      // 카테고리 이름들 가져오기
      final List<Map<String, dynamic>> catResult = await db.rawQuery('''
        SELECT c.name FROM categories c
        JOIN plant_categories pc ON c.id = pc.category_id
        WHERE pc.plant_id = ?
      ''', [plantId]);

      // 물 주기 이력 가져오기
      final List<Map<String, dynamic>> historyResult = await db.query(
        'watering_history', where: 'plant_id = ?', whereArgs: [plantId], orderBy: 'date DESC'
      );
      // **업데이트1 오류- 비료 주기 날자 DB에서 불러오기 실패
      final List<Map<String, dynamic>> fhistoryResult = await db.query(
       'fertilizer_history', where: 'plant_id = ?', whereArgs: [plantId], orderBy: 'date DESC'
      );

      plants.add(Plant.fromMap(
        map,
        categories: catResult.map((c) => c['name'] as String).toList(),
        wHistory: historyResult.map((h) => h['date'] as String).toList(),
        fHistory: fhistoryResult.map((f) => f['date'] as String).toList(),
      ));
    }
    return plants;
  }

  // 3. 삭제 (드래그 삭제 기능 대응)
  static Future<void> deletePlant(String id) async {
    final db = await AppDatabase.instance.database;
    // ON DELETE CASCADE 설정 덕분에 연결된 이력과 카테고리 링크도 자동 삭제됩니다.
    await db.delete('plants', where: 'id = ?', whereArgs: [id]);
  }

  // ✅ 물 주기 실행 시 호출 (기본 정보 업데이트 + 이력 추가)
  Future<void> dbWaterPlant(String plantId, String date) async {
    final db = await AppDatabase.instance.database;

    await db.transaction((txn) async {
      // 1. plants 테이블의 last_watered 날짜 갱신 (날짜 계산용)
      await txn.update(
        'plants',
        {'last_watered': date},
        where: 'id = ?',
        whereArgs: [plantId],
      );

      // 2. watering_history 테이블에 새로운 이력 추가
      await txn.insert('watering_history', {
        'plant_id': plantId,
        'date': date,
      });
    });
  }

  static Future<void> dbFertilizePlant(String plantId, String date) async {
    final db = await AppDatabase.instance.database;
    // 비료는 이력 테이블에만 insert 수행
    await db.insert('fertilizer_history', {
      'plant_id': plantId,
      'date': date,
    });
  }
}