//상태 관리 - 모든 식물 데이터 보관
//화면 전환 - InputScreen ↔ ListScreen
//사이드바 관리 - 햄버거 메뉴 + Drawer
//CRUD 작업 - Create, Update, Delete
//카테고리 필터링
import 'package:flutter/material.dart';
import 'package:plantapp_p/Data/data.dart';
import '../models/plant.dart';
import '../presentation/app_colors.dart';
import 'list_screen.dart';
import 'input_screen.dart';
//import 'alarm.dart';
import 'package:plantapp_p/Data/plant_repository.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'app_theme.dart';
//import 'package:flutter_local_notifications/flutter_local_notifications.dart';


// App.tsx 변환
class HomeScreen extends StatefulWidget { //StatefulWidget-> 변하지 않는 고정된 위젯을 해당 클래스에 사용
  const HomeScreen({super.key}); //(생성자)

  @override
  State<HomeScreen> createState() => _HomeScreenState();
  //StatefulWidget은 항상 두개의 클래스가 짝을 이뤄 작동
  //위젯 클래스 (HomeScreen) - 화면의 겉모양을 담당하지만 실제 데이터 담지 않음 (설계도)
  //상태 클래스 (_HomeScreenState) - 실제 데이터를 보관하고, 데이터 바뀌면 화면을 다시 그리라고 명령 (실제 동작)
}

class _HomeScreenState extends State<HomeScreen> {
  // State - App.tsx의 useState 변환
  String _currentScreen = 'list'; // '입력' 인지 '리스트' 인지 
  bool _isSidebarOpen = false; //메뉴가 열려있는지 결정하는 전역 상태
  String? _selectedCategory; //선택된 카테고리
  Set<String> _selectedPlantIds = {};//선택된 카테고리 id

  //bool _isAlarmEnabled = true; // 알림 켜짐 상태
  //TimeOfDay _notificationTime = const TimeOfDay(hour: 9, minute: 0);
  
  // 예제 데이터 (App.tsx의 초기 plants)
  late List<Plant> _plants; //제네릭을 사용하여 Plant 객체만 들어올수 있는 리스트 만듬 디버그 오류?
  //late->지금당장은 비어있지만 사용전에는 반드시 초기화

  @override
  void initState() { 
    super.initState();
    _initializeApp(); // 순차적 초기화 함수 호출
  }

  // 💡 새롭게 만든 통합 초기화 함수
  Future<void> _initializeApp() async {
    // 1. 권한부터 먼저 확실히 물어봅니다.
    await _requestInitialPermissions();

    // 2. DB에서 식물 데이터를 '완벽하게' 다 불러올 때까지 기다립니다.
    await _initializePlants();
    AppDatabase.instance.cleanOldHistory();

    // 3. 식물 데이터가 준비된 후 알람 설정을 불러오고 예약합니다.
    /*if (mounted) {
      await _initAlarmSettings();//OS가 설정 내용 기억
    }*/
  }

  //데이터베이스 긁어옴
  Future<void> _initializePlants() async{
      try {
      // 리스트 형태의 Map 데이터를 getAllPlants에서 리스트로 다시변환해서 보내줌
      final List<Plant> loadedPlants = await PlantRepository.instance.getAllPlants();

      // 화면 갱신
      setState(() {
        _plants = loadedPlants;
      });
    } catch (e) {
      debugPrint("DB 로드 에러: $e");
      // 에러 발생 시 사용자에게 알림을 주는 로직을 추가할 수 있습니다.
    }
  }
  
  Future<void> _requestInitialPermissions() async {
    // 1. 현재 권한 상태 먼저 확인 (사전 체크)
    var photosStatus = await Permission.photos.status;
    
    // (옵션) 안드로이드 12 이하 호환성을 위해 storage 상태도 함께 체크
    var storageStatus = await Permission.storage.status;

    // 2. 이미 허용(Granted)되었거나, 일부 허용(Limited) 상태라면 아무 작업도 하지 않고 스킵!
    if (photosStatus.isGranted || photosStatus.isLimited || storageStatus.isGranted) {
      print("갤러리 권한이 이미 허용되어 있습니다.");
      return; // 여기서 함수 즉시 종료 (팝업 안 띄움)
    }
      // 갤러리 접근 권한 상태 확인
      // 안드로이드 버전 및 iOS에 따라 Photos 또는 Storage를 사용합니다.
      // 1. 갤러리 및 알림 권한 목록 정의
    Map<Permission, PermissionStatus> statuses = await [
      Permission.photos,       // 갤러리 권한
      //Permission.notification, // 알림 권한 (추가된 부분)
      Permission.storage, // 구버전 안드로이드용
    ].request();

    /* 2. 알림 권한 결과 확인
    if (statuses[Permission.notification]!.isGranted) {
      print("알림 권한이 허용되었습니다.");
    } else if (statuses[Permission.notification]!.isPermanentlyDenied) {
      print("권한이 거부되었습니다./n 알림 기능을 이용하시려면 '설정'에서 관련 권한을 허용해주세요:)");
    }*/
    // 4. 요청 후 결과 확인
    final newPhotosStatus = statuses[Permission.photos];
    final newStorageStatus = statuses[Permission.storage];

    // 5. 갤러리 권한 결과 확인
    if (newPhotosStatus!.isGranted || newPhotosStatus.isLimited || newStorageStatus!.isGranted) {
      print("갤러리 권한이 허용되었습니다.");
    } else if (newPhotosStatus.isPermanentlyDenied || newStorageStatus!.isPermanentlyDenied) {
      // 사용자가 '다시 묻지 않음'을 선택하고 거절한 경우
      //_showPermissionDialog(); // 설정 이동 안내 다이얼로그 호출 (추천)
      print("권한이 거부되었습니다./n 이미지 기능을 이용하시려면 '설정'에서 관련 권한을 허용해주세요:)");
    }

    //정확한 시간 계산 알람
    //final androidPlugin = FlutterLocalNotificationsPlugin()
    //  .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  
  //await androidPlugin?.requestExactAlarmsPermission();
  }

  /*Future<void> _initAlarmSettings() async {
    // 저장된 값을 가져옴
    final settings = await AlarmService.loadSettings();

    // 2. 위젯이 아직 화면에 살아있는지 안전 검사 (플러터 권장 사항)
    if (!mounted) return;
    
    setState(() {
      _isAlarmEnabled = settings['isEnabled'];
      _notificationTime = TimeOfDay(hour: settings['hour'], minute: settings['minute']);
    });
    
    // 불러온 설정으로 시스템 알람 예약 갱신
    await _refreshWateringAlarm(_plants);
  }*/

  // CREATE -> 따로 DB 접근 로직 존재
  //새로운 식물 추가하고 화면을 다시 list로 돌려놓음
  void _addPlant(Plant plant) {
    setState(() { //바뀐 데이터를 바탕으로 화면을 다시 그림
      _plants.add(plant);
      _currentScreen = 'list';
    });
  }

  // UPDATE ->물을 주는등 사소한 변화 있을때
  void _updatePlant(Plant updatedPlant) async{

    await PlantRepository.instance.updatePlant(updatedPlant);

    setState(() { 
      final index = _plants.indexWhere((p) => p.id == updatedPlant.id); //수정할 식물이 리스트의 몇번째 칸에 있는지 찾음
      if (index != -1) {
        _plants[index] = updatedPlant;
      }
    });
  }

  // DELETE -> 따로 DB 접근 로직 존재?
  void _deletePlant(String plantId) {
    setState(() {
      _plants.removeWhere((p) => p.id == plantId);
    });
  }
  //스크린 변화?
  void _navigateTo(String screen) {
    setState(() {
      _currentScreen = screen;
      _isSidebarOpen = false;
      _activeSearchQuery = '';
    });
  }

  void _selectCategory(String? category) {
    setState(() {
      _selectedCategory = category;
      _currentScreen = 'list';
      _isSidebarOpen = false;
    });
  }

  //데이터 일괄 처리(물 준 날짜 한번에 업데이트)
  void _handleWaterSelectedPlants() async{
    final today = DateTime.now().toIso8601String().split('T')[0];

    await Future.wait(_selectedPlantIds.map((id) => 
    PlantRepository.instance.dbWaterPlant(id, today)
  ));
    
    setState(() {
      for (final plantId in _selectedPlantIds) { //체크박스 선택된 식물들의 아이디
        final index = _plants.indexWhere((p) => p.id == plantId);//원본 식물 찾기 
      if (index != -1) {
        final plant = _plants[index];
        _plants[index] = plant.copyWith( //copywith를 통해 현제 화면 데이터 수정
          lastWatered: today,
          wateringHistory: [...plant.wateringHistory, today],
        );
      }
    }
      _selectedPlantIds.clear();
      //_refreshWateringAlarm(_plants);
    });
  }

  //비료 날짜 업데이트
  void _handleFertilizeSelectedPlants() async{
    final today = DateTime.now().toIso8601String().split('T')[0];

    // 1. DB 일괄 업데이트 (비료 이력 추가)
    await Future.wait(_selectedPlantIds.map((id) => 
    PlantRepository.dbFertilizePlant(id, today)
  ));
    setState(() {
      for (final plantId in _selectedPlantIds) {
      final index = _plants.indexWhere((p) => p.id == plantId);
      if (index != -1) {
        final plant = _plants[index];
        // 비료 이력 리스트에 오늘의 날짜 추가한 복사본 생성
        _plants[index] = plant.copyWith(
          fertilizerHistory: [...plant.fertilizerHistory, today],
        );
      }
    }
      _selectedPlantIds.clear();
    });
    
  }

  void _sendEmail() async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: 'yoohyun031217@gmail.com', // 👈 여기에 고객 문의를 받을 이메일을 적으세요.
      query: 'subject=[식물 관리 앱 문의]&body=문의 내용을 작성해 주세요.(휴대폰 기종 정보와 에러 상황에 대한 자세한 설명이 포함되면 더욱 구체적인 답변이 가능합니다!)', // 제목과 본문 미리 채우기
    );

    try {
      if (await canLaunchUrl(emailLaunchUri)) {
        await launchUrl(emailLaunchUri);
      } else {
        throw '메일 앱을 열 수 없습니다.';
      }
    } catch (e) {
      // 메일 앱이 없는 경우 등을 대비한 안내
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('메일 앱을 찾을 수 없습니다.')),
      );
    }
  }

  /*Future<void> _refreshWateringAlarm(List<Plant> plants) async {
    // 1. 모델에 만든 needsWaterToday 로직을 활용해 개수 파악
    //int needWaterCount = plants.where((p) => p.needsWaterToday).length;

    int totalPlantCount = plants.length;

    // 2. AlarmService를 통해 실제 시스템 알람 예약
    // 사이드바 설정값(켜짐 여부, 시간)을 가져와서 넣어주면 더 완벽합니다.
    await AlarmService.scheduleDailyWateringAlarm(
      plantCount: totalPlantCount,
      hour: _notificationTime.hour,      // 설정된 시간 (기본값 9시)
      minute: _notificationTime.minute,
      isEnabled: _isAlarmEnabled, // 설정된 알림 켜짐 여부
    );

    await AlarmService.saveSettings(
    _isAlarmEnabled, 
    _notificationTime.hour, 
    _notificationTime.minute
  );
  
  print("알람 시스템 예약 완료: 오늘 $totalPlantCount개 대상");
}*/

void _showSettingsDialog() {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          // 현재 다크 모드인지 확인
          bool isDarkMode = AppTheme.themeNotifier.value == ThemeMode.dark;

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('설정', style: TextStyle(fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 🌙 다크 모드 스위치 추가!
                SwitchListTile(
                  title: const Text('다크 모드'),
                  subtitle: Text(isDarkMode ? '다크 테마 사용 중' : '밝은 테마 사용 중'),
                  value: isDarkMode,
                  activeColor: AppColors.primaryBlue, // 테마 컬러 사용
                  onChanged: (bool value) async{
                    // 1. 팝업창 UI 갱신 (스위치 움직임)
                    setDialogState(() {}); 
                    
                    // 2. 전역 테마 상태 변경! -> 값이 바뀌는 순간 앱 전체가 즉시 다시 그려짐
                    AppTheme.themeNotifier.value = value ? ThemeMode.dark : ThemeMode.light;
                    
                    // 2. 💾 내부 저장소에 데이터 저장
                    await AppTheme.saveTheme(value);
  
                  // 3. 팝업창 UI 갱신 (StatefulBuilder 내부에 있으므로)
                  setDialogState(() {});
                  },
                ),
                const Divider(),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('닫기'),
              ),
            ],
          );
        },
      );
    },
  );
}

void _showAppInfo(BuildContext context) {
  showAboutDialog(
    context: context,
    applicationName: '식물 관리 앱 (Plant Management App)',
    applicationVersion: '1.1.1',
    applicationIcon: ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.asset(
        'assets/images/PlantApp_Icon.png',
        width: 50,
        height: 50,
      ),
    ),
    applicationLegalese: '© ${DateTime.now().year} 이유현. All rights reserved.',
    children: [
      const SizedBox(height: 20),
      // 1. 이미지 출처
      const Text(
        '기본 이미지 및 사진 삽입 배경 이미지 출처',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      const Text('Designed by Freepik'),
      const SizedBox(height: 15),

      // 2. 개발자 문의
      const Text(
        '개발자 문의',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      const Text('• 이메일: yoohyun031217@gmail.com'),
      const SizedBox(height: 15),

      // 3. 개인정보 처리 방침 (텍스트 버튼 형태)
      TextButton(
        onPressed: () {
          // TODO: 개인정보 처리 방침 팝업이나 웹뷰 연결
          _showPrivacyPolicy(context);
        },
        child: const Text('개인정보 처리 방침 확인하기'),
      ),
    ],
  );
}

void _showPrivacyPolicy(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('개인정보 처리 방침'),
        content: const SingleChildScrollView(
          child: Text(
            '1. 본 앱은 사용자가 입력한 식물 정보를 서버로 전송하지 않으며, 기기 내부 저장소에만 보관합니다.\n\n'
            '2. 사용자의 이메일 등 개인 식별 정보는 문의하기 기능을 이용할 때 외에는 수집하지 않습니다.\n\n'
            '3. 권한 수집 안내\n'
            '- 사용자는 식물 사진 등록을 위해 갤러리 접근 권한을 허용할 수 있습니다.\n'
            //'- 알람 기능을 위해 시스템 알림 권한을 사용합니다.\n'
            '- 선택 권한은 거부하더라도 앱의 다른 기능은 이용 가능하지만, 사진 등록 기능과 알람에 대한 기능은 제한될 수 있습니다.'
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      );
    },
  );
}

  // 카테고리 정렬
  List<String> get _allCategories { //get ->함수를 ()없이 변수처럼 사용하게 해줌
    final categories = <String>{}; //Set
    for (final plant in _plants) {
      categories.addAll(plant.categories); //각 plant가 가지고있는 카테고리를 categories라는 주머니에 쏟아붓는다
    }
    final list = categories.toList(); //Set형태 다시 List로 바꿈
    list.sort();
    return list;
  }

  // 사용자가 특정 카테고리 선택하면 포함된 식물만 보여줌
  List<Plant> get _filteredPlants {
    return _plants.where((p) {
      // A. 검색어가 있다면 이름 검색 수행
      if (_activeSearchQuery.isNotEmpty) {
        return p.name.toLowerCase().contains(_activeSearchQuery.toLowerCase());
      }
      
      // B. 검색어가 없고 카테고리가 선택되었다면 카테고리 필터 수행
      if (_selectedCategory != null) {
        return p.categories.contains(_selectedCategory);
      }
      
      // C. 아무 조건도 없으면 전체 반환
      return true;
    }).toList();
    //where ->리스트의 요소들을 검사해 참인 것들만 골라냄
    //(p) => ... -> 리스트에서 꺼낸 식물 한 개를 임시로 p라고 부름
    //p가 가진 카테고리중 선택한 가테고리 있는지 확인 -> 이후 결과물들 list로 포장
  }

 final TextEditingController _searchController = TextEditingController();
 String _activeSearchQuery = ''; // 실제 필터링에 사용될 검색어

  void _handleSearch() {
    if (_searchController.text.trim().isEmpty) return; // 빈 값은 무시
    final query = _searchController.text.trim();

    setState(() {
    _activeSearchQuery = query; // 검색어 확정
    _selectedCategory = null;   // 검색 시 카테고리 필터는 해제
    _currentScreen = 'list';    // 리스트 화면으로 이동
    _isSidebarOpen = false;     // 사이드바 닫기
  });

    _searchController.clear();     // 검색창 초기화
  }

  void _showUsageGuide(BuildContext context) {
  // 준비하신 가이드 이미지 경로 리스트
  final List<String> guideImages = [
    'assets/images/6.jpg',
    'assets/images/7.jpg',
    'assets/images/8.jpg',
    'assets/images/9.jpg',
    'assets/images/10.jpg',
  ];

  // 페이지 컨트롤러 선언
  final PageController _pageController = PageController();

  showDialog(
    context: context,
    builder: (context) {
      int _currentPage = 0;

      return StatefulBuilder(
        builder: (context, setDialogState) {
          // 1. 화면 사이즈 가져오기
          final screenSize = MediaQuery.of(context).size;

          return Dialog(
            // 2. 배경색 및 모서리 둥글게
            backgroundColor: Colors.transparent, // 배경 투명 (Container에서 조절)
            elevation: 0,
            insetPadding: const EdgeInsets.symmetric(horizontal: 20), // 좌우 여백
            child: Container(
              // 3. 팝업의 가로/세로 비율 직접 설정 (화면의 80% 정도)
              width: screenSize.width * 0.85,
              height: screenSize.height * 0.7, 
              decoration: BoxDecoration(
                color: Colors.black, // 이미지 배경은 검은색
                borderRadius: BorderRadius.circular(20),
              ),
              clipBehavior: Clip.antiAlias, // 자식 위젯들도 둥글게 깎음
              child: Stack(
                children: [
                  // 1. 이미지 슬라이더
                  PageView.builder(
                    controller: _pageController,
                    itemCount: guideImages.length,
                    onPageChanged: (int page) {
                      setDialogState(() => _currentPage = page);
                    },
                    itemBuilder: (context, index) {
                      return InteractiveViewer(
                        child: Image.asset(
                          guideImages[index], 
                          fit: BoxFit.contain,
                        ),
                      );
                    },
                  ),

                  // 2. 상단 우측 닫기 버튼
                  Positioned(
                    top: 10,
                    right: 10,
                    child: CircleAvatar(
                      backgroundColor: Colors.black.withOpacity(0.5),
                      radius: 18,
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ),

                  // 3. 하단 페이지 점(Dot Indicator)
                  Positioned(
                    bottom: 20, // 팝업 안쪽으로 위치 조정
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        guideImages.length,
                        (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          height: 8,
                          width: _currentPage == index ? 20 : 8,
                          decoration: BoxDecoration(
                            color: _currentPage == index 
                                ? Colors.white 
                                : Colors.white.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

  //메인 레이아웃 구성
  // 1.헤더 밑에 공간을 하나 만들고, 상태에 따라 '입력창'이나 '목록창'을 끼워 넣어라.
  // 2.그리고 자식 창에서 무슨 일이 생기면 나(부모)한테 바로 보고해라!
  @override
  Widget build(BuildContext context) {

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold( //기본 캔버스(배경색 설정, 자식 위젯 올림)
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Center(
        child: Container(
          // 모바일 환경에 맞춰 가로폭 제한
          constraints: const BoxConstraints(maxWidth: 430),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
                blurRadius: 20,
                offset: const Offset(0, 0),
              ),
            ],
          ),
          child: Stack( //포스트잇 처럼 겹겹이 위젯 쌓음 (순서 중요)
            children: [
              // Main Content
              Column( //헤더와 내용 새로로 배치
                children: [
                  // Header
                  _buildHeader(),
                  
                  // Screen Content
                  Expanded( //남은 공간(헤더와 사이드바 이후) 전부 사용
                    child: _currentScreen == 'input'
                        ? InputScreen(onSave: _addPlant)
                        : ListScreen(
                          //각 화면을 부를때 데이터와 함수등을 같이 넘겨줌
                           //listscreen의 plants 변수에 homescreen의 filterPlants 값 넣어줌
                            plants: _filteredPlants, //선택된 카테고리의 식물들
                            onUpdate: _updatePlant, //식물 정보 업데이트(간단한 물 주기등)
                            onDelete: _deletePlant, //식물 삭제 ->함수를 넘겨주면 자식에서 사용해도 부모의 값을 바꿀 수 있다
                            selectedPlantIds: _selectedPlantIds, //선택된 식물들의 아이디
                            onSelectionChange: (newSelection) {
                              setState(() {
                                _selectedPlantIds = newSelection; //해당부분이 리스트에 값 추가
                              });
                            },
                            onDataChanged: () async {
                              // 1. DB에서 최신 식물 리스트를 다시 가져옴
                              final updatedPlants = await PlantRepository.instance.getAllPlants(); 
                              
                              setState(() {
                                _plants = updatedPlants; // 메인 데이터 갱신 -> 리스트가 자동으로 다시 그려짐(_filteredPlants로 한번더 갱신?)
                              });
                              //  여기서 home_screen이 가진 변수들을 그대로 사용하여 알람 갱신
                              //await _refreshWateringAlarm(_plants); 
                              _selectedPlantIds.clear();
                            },
                          ),
                  ),
                ],
              ),

              //기존의 if문에 한번에 담는건 위젯이 즉시 스택에 생성되고 이후 다시한번 사이드바가 나오기때문에 수정

              // Overlay (배경 어둡게)
            if (_isSidebarOpen)
              Positioned.fill( // 전체를 채우되 사이드바 영역만 GestureDetector로 제어
                child: GestureDetector(
                  onTap: () => setState(() => _isSidebarOpen = false),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    color: Colors.black.withOpacity(isDark ? 0.7 : 0.5),
                  ),
                ),
              ),

            // Sidebar (if 조건을 지우고 AnimatedPositioned로 감싸기)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                left: _isSidebarOpen ? 0 : -264, // 열리면 0, 닫히면 화면 왼쪽 밖으로 -264
                top: 0,
                bottom: 0,
                child: SizedBox(
                  width: 264,
                  child: _buildSidebar(),
                  ),
              ),

            ],
          ),
        ),
      ),
    );
  }

  // Header Widget
  Widget _buildHeader() { //현재 어떤 화면을 보는지에 따라 다른 헤더 붙여줌

  final theme = Theme.of(context);
  final colorScheme = theme.colorScheme;

    return Container( //외형 컨테이너 정의
      color: colorScheme.surface, 
    child: SafeArea(
      // bottom: false를 설정하여 하단 여백은 무시하고 상단(상태바) 여백만 확보합니다.
      bottom: false, 
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: theme.dividerColor, 
              width: 1,),
          ),
        ),
      child: _currentScreen == 'input' //해당 위젯에 들어갈 내용물(기능)
          ? _buildInputHeader()
          : _buildListHeader(),
    ),
    ),
  );
}

  // Input Screen Header
  Widget _buildInputHeader() {
    // 💡 매번 Theme.of(context)를 쓰기 길어지니 변수에 담아둡니다.
  final colorScheme = Theme.of(context).colorScheme;

  return Padding(
    padding: const EdgeInsets.all(12.0),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center, // 수직 정렬을 가운데로 변경하여 가독성 향상
      children: [
        // Hamburger Menu
        IconButton(
          onPressed: () => setState(() => _isSidebarOpen = true),
          icon: Icon(Icons.menu, color: colorScheme.onSurface),
          padding: const EdgeInsets.all(8),
          constraints: const BoxConstraints(), // 아이콘 버튼의 기본 여백 최소화
        ),
        const SizedBox(width: 8), // 여백을 조금 줄임
        
        Expanded(
          child: Row(
            children: [
              // 1. 앱 아이콘
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  'assets/images/PlantApp_Icon.png',
                  width: 36, // 크기를 살짝 줄임 (40 -> 36)
                  height: 36,
                ),
              ),
              const SizedBox(width: 10),
              
              // 2. 앱 이름과 버전 정보 (Flexible로 감싸 오버플로우 방지)
              Flexible( 
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '식물 관리 앱 (Plant Management App)',
                      style: TextStyle(
                        fontSize: 13, // 크기 축소 (15 -> 13)
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface.withOpacity(0.8), // 라이트/다크 모두 잘 보이는 부드러운 텍스트
                      ),
                      overflow: TextOverflow.ellipsis, // 공간 부족 시 '...' 처리
                      maxLines: 1, // 한 줄로 고정
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'Version 1.1.1',
                      style: TextStyle(
                        fontSize: 10, // 크기 축소 (12 -> 10)
                        color: AppColors.gray400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

  // List Screen Header
  Widget _buildListHeader() {

    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Hamburger Menu
          IconButton(
            onPressed: () => setState(() => _isSidebarOpen = true),
            icon: Icon(Icons.menu, color: colorScheme.onSurface),
            padding: const EdgeInsets.all(8),
          ),
          
          // Title (중앙)
          Text(
            _selectedCategory ?? '내 식물',
            style: TextStyle(
              fontSize: 18,
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
          
          // Action Buttons
          Row(
            children: [
              // Fertilizer Button (초록 잎)
              _buildActionButton(
                icon: Icons.eco,
                color: colorScheme.secondary,
                onPressed: _selectedPlantIds.isEmpty
                    ? null
                    : _handleFertilizeSelectedPlants,
              ),
              const SizedBox(width: 8),
              
              // Water Button (파란 물방울)
              _buildActionButton(
                icon: Icons.water_drop,
                color: colorScheme.primary,
                onPressed: _selectedPlantIds.isEmpty
                    ? null
                    : _handleWaterSelectedPlants,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Action Button Widget
  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    VoidCallback? onPressed,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        disabledBackgroundColor: color.withOpacity(0.5),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        minimumSize: const Size(40, 36),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
        ),
      ),
      child: Icon(icon, size: 16),
    );
  }

  // Sidebar Widget
  Widget _buildSidebar() {

  final theme = Theme.of(context);
  final colorScheme = theme.colorScheme;

  return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 30,
          ),
        ],
      ),
      child: SafeArea( // 상태바 영역 침범 방지
        child: Column(
          children: [
            // 1. Sidebar Header (고정 영역)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: theme.dividerColor),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '메뉴',
                    style: TextStyle(
                      fontSize: 18,
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(() => _isSidebarOpen = false),
                    icon: Icon(Icons.close, size: 20, color: colorScheme.onSurface.withOpacity(0.6)),
                    padding: const EdgeInsets.all(8),
                  ),
                ],
              ),
            ),
            
            // 2. Menu Items (스크롤 가능 영역)
            Expanded(
              child: Scrollbar( // 사용자가 위치를 알 수 있게 스크롤바 추가
                thumbVisibility: true, // 항상 스크롤바 표시 여부 (선택 사항)
                child: SingleChildScrollView(
                  primary: false,
                  physics: const BouncingScrollPhysics(), // 부드러운 스크롤 느낌
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      children: [
                        _buildMenuItem(
                          icon: Icons.add_circle_outline,
                          label: '입력 화면',
                          isSelected: _currentScreen == 'input',
                          onTap: () => _navigateTo('input'),
                        ),
                        _buildMenuItem(
                          icon: Icons.list,
                          label: '전체 식물',
                          isSelected: _currentScreen == 'list' && _selectedCategory == null,
                          onTap: () {
                            _selectCategory(null);
                            _navigateTo('list');
                          },
                        ),
                        _buildMenuItem(
                          icon: Icons.settings_outlined,
                          label: '설정',
                          isSelected: false,
                          onTap: () {
                            setState(() => _isSidebarOpen = false); // 상태 동기화
                            _showSettingsDialog();
                          },
                        ),
                        _buildMenuItem(
                          icon: Icons.help_outline,
                          label: '사용 가이드',
                          isSelected: false,
                          onTap: () {
                            // 1. 먼저 열려있는 사이드바를 닫습니다.
                            setState(() => _isSidebarOpen = false);
                            
                            // 2. 가이드 화면(이미지 슬라이드)을 띄웁니다.
                            _showUsageGuide(context);
                          },
                        ),
                        
                        // Name Search
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: TextField(
                            controller: _searchController,
                            onSubmitted: (_) => _handleSearch(),
                            style: TextStyle(fontSize: 14, color: colorScheme.onSurface),
                            decoration: InputDecoration(
                              hintText: '식물 이름 검색',
                              hintStyle: TextStyle(
                                fontSize: 14, 
                                color: colorScheme.onSurface.withOpacity(0.4)
                              ),
                              prefixIcon: GestureDetector(
                                onTap: _handleSearch,
                                child: Icon(Icons.search, size: 20, color: colorScheme.onSurface.withOpacity(0.6)),
                              ),
                              enabledBorder: UnderlineInputBorder(
                                borderSide: BorderSide(color: theme.dividerColor, width: 1),
                              ),
                              focusedBorder: UnderlineInputBorder(
                                borderSide: BorderSide(color: colorScheme.primary, width: 2),
                              ),
                              contentPadding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),

                        // Categories
                        if (_allCategories.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                '카테고리',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colorScheme.onSurface.withOpacity(0.5),
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                          ..._allCategories.map((category) => _buildCategoryItem(category)), 
                        ],
                        const Divider(),
                        ListTile(
                          leading: const Icon(Icons.contact_support_outlined),
                          title: const Text('고객 문의'),
                          subtitle: const Text('불편한 점이나 제안사항을 보내주세요', style: TextStyle(fontSize: 12)),
                          onTap: _sendEmail,
                        ),
                        ListTile(
                          leading: const Icon(Icons.info_outline),
                          title: const Text('앱 정보'),
                          onTap: () => _showAppInfo(context),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
  );
}

  // Menu Item Widget
  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
  final theme = Theme.of(context);
  final colorScheme = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primary.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? colorScheme.primary : colorScheme.onSurface.withOpacity(0.7),
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: isSelected ? colorScheme.primary : colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Category Item Widget
  Widget _buildCategoryItem(String category) {
    final isSelected = _selectedCategory == category;

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return InkWell(
      onTap: () => _selectCategory(category),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.secondary.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              Icons.local_offer,
              size: 16,
              color: isSelected ? colorScheme.secondary : colorScheme.onSurface.withOpacity(0.7),
            ),
            const SizedBox(width: 12),
            Text(
              category,
              style: TextStyle(
                fontSize: 14,
                color: isSelected ? colorScheme.secondary : colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}