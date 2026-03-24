import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class AppDatabase {
  // 싱글톤 패턴: 앱 전체에서 하나의 데이터베이스 인스턴스만 공유
  static final AppDatabase instance = AppDatabase._init();
  static Database? _database;
  static const int _databaseVersion = 1;
  static const String _databaseName = "plant_app.db";

  AppDatabase._init(); //프라이빗 생성자(다른곳에서 생성 금지)

  // 데이터베이스 가져오기 (없으면 초기화)
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB(_databaseName); //앱 처음 실행시 실제 파일 연결
    return _database!;
  }

  // 데이터베이스 파일 경로 설정 및 오픈
  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath(); //안드로이드나 ios기기마다 데이터베이스가 저정되는 시스템 경로가 다르기 때문에 안전한 전용 폴더 주소를 알아내어 가져옴
    final path = join(dbPath, filePath); //폴더 주소와 파일 이름 합쳐 전체경로 만듬

    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _createDB,
      // 외래 키(Foreign Key) 활성화 (연쇄 삭제 기능을 위해 필수)
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
  print("버전 업데이트 감지: $oldVersion -> $newVersion");
  
  // 미래의 내가 여기서 작업할 예정...
  // if (oldVersion < 2) { ... }
}

  // 테이블 생성 (스키마 정의),   async - 앱이 렉걸리지 않게 업무 배분하는 멀티태스킹 기술(비동기)
  Future _createDB(Database db, int version) async {
    const textType = 'TEXT NOT NULL';
    const textTypeNullable = 'TEXT';
    const integerType = 'INTEGER NOT NULL';
    const idType = 'TEXT PRIMARY KEY';

    // 1. 식물 기본 정보 테이블
    await db.execute('''
      CREATE TABLE plants (
        id $idType,
        name $textType,
        image_url $textTypeNullable,
        watering_frequency INTEGER,
        last_watered $textTypeNullable,
        notes $textTypeNullable
      )
    ''');

    // 2. 카테고리 마스터 테이블
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT UNIQUE NOT NULL
      )
    ''');

    // 3. 식물-카테고리 연결 테이블 (다대다)
    await db.execute('''
      CREATE TABLE plant_categories (
        plant_id TEXT,
        category_id INTEGER,
        PRIMARY KEY (plant_id, category_id),
        FOREIGN KEY (plant_id) REFERENCES plants (id) ON DELETE CASCADE,
        FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE CASCADE
      )
    ''');
    //ON DELETE CASCADE - plant_id 삭제되면 포함된 category_id도 같이 삭제

    // 4. 물 주기 이력 테이블 (일대다)
    await db.execute('''
      CREATE TABLE watering_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        plant_id TEXT,
        date $textType,
        FOREIGN KEY (plant_id) REFERENCES plants (id) ON DELETE CASCADE
      )
    ''');

    // 5. 비료 주기 이력 테이블 (일대다)
    await db.execute('''
      CREATE TABLE fertilizer_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        plant_id TEXT,
        date $textType,
        FOREIGN KEY (plant_id) REFERENCES plants (id) ON DELETE CASCADE
      )
    ''');
  }

  // 데이터베이스 닫기
  Future close() async {
    final db = await instance.database;
    db.close();
  }

  Future<void> cleanOldHistory({int keepCount = 5}) async {
    final db = await instance.database;
    
    // 갯수 제한
    await db.execute('''
    DELETE FROM watering_history 
    WHERE id NOT IN (
      SELECT id 
      FROM watering_history AS w2 
      WHERE w2.plant_id = watering_history.plant_id
      ORDER BY w2.date DESC 
      LIMIT $keepCount
    )
  ''');

    await db.execute('''
    DELETE FROM fertilizer_history 
    WHERE id NOT IN (
      SELECT id 
      FROM fertilizer_history AS f2 
      WHERE f2.plant_id = fertilizer_history.plant_id
      ORDER BY f2.date DESC 
      LIMIT $keepCount
    )
  ''');
  
  } 
}