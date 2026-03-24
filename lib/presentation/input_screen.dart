//식물 목록 표시 (ListView), 긴급도 순 정렬 - 물이 급한 식물부터ㅁ
//다중 선택 - 체크박스로 여러 식물 선택, 드래그 삭제 - 상하로 드래그하면 삭제
import 'package:flutter/material.dart';
import '../models/plant.dart';
//import '../presentation/app_colors.dart';
import '../Data/plant_repository.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:path/path.dart' as p; //이미지 최적화
import 'package:path_provider/path_provider.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:permission_handler/permission_handler.dart';

Future<String> compressImage(String path) async { //전역 함수
    final appDir = await getApplicationDocumentsDirectory(); //임시폴더 위치 알아냄 (압축된 사진 임시저장)
    final String fileName = "${DateTime.now().millisecondsSinceEpoch}.jpg";
    final String targetPath = p.join(appDir.path, fileName); //이름 붙여 저장

    // 이미지 압축 실행
    final XFile? compressedFile = await FlutterImageCompress.compressAndGetFile(
      path,              // 원본 경로
      targetPath,        // 저장될 경로
      quality: 80,       // 압축률 (0~100, 80 정도가 화질 대비 용량이 가장 효율적임)
      minWidth: 1024,    // 가로 최대 크기 제한 (비율 유지하며 축소)
      minHeight: 1024,   // 세로 최대 크기 제한
      format: CompressFormat.jpeg, // 용량이 가장 적은 JPEG 포맷 권장
    );

    return compressedFile?.path ?? path; // 압축 실패 시 원본 경로 반환
}

// 사용자에게 권한 허용을 요청하는 다이얼로그 함수
void showPermissionRequestDialog(BuildContext context) {
  showDialog(
    context: context, //화면 띄울 위치
    barrierDismissible: false, // 배경 터치로 닫기 방지
    builder: (BuildContext context) => AlertDialog(
      title: const Text('갤러리 접근 권한 필요'),
      content: const Text(
        '식물 사진을 등록하기 위해서는 갤러리 접근 권한이 반드시 필요합니다.\n\n'
        '지금 설정 화면으로 이동하여 [사진] 권한을 허용해 주세요.'
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('나중에', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            openAppSettings(); // ⚙️ 휴대폰의 앱 설정 화면으로 즉시 이동
          },
          child: const Text('설정으로 이동'),
        ),
      ],
    ),
  );
}

void showStorageFullDialog(BuildContext context) {
  showDialog(
    context: context, // 전역 함수라면 인자로 전달받기
    builder: (context) => AlertDialog(
      title: const Text('저장공간 부족'),
      content: const Text(
        '휴대폰의 저장공간이 부족하여 데이터를 저장할 수 없습니다.\n\n'
        '불필요한 앱이나 파일을 정리한 후 다시 시도해 주세요.'
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('확인'),
        ),
      ],
    ),
  );
}

// InputScreen.tsx 변환
class InputScreen extends StatefulWidget {
  //onSave 정의- 식물 정보가 입력되면 결과물(Plant 객체)를 부모에게 전달 -Home 화면 갱신
  final Function(Plant) onSave;//Plant 객체 하나를 매개변수로 받는 함수를 담는 주머니

  const InputScreen({//생성자
    super.key,
    required this.onSave, //위젯이 생성될때 onSave 넘겨 받아야함
  });

  @override //상속받은 기능 재정의 (createState)
  State<InputScreen> createState() => _InputScreenState();
  //리턴타입          화면 생성시 호출    = { return _InputScreenState(); }(실제 동작할 클래스)
}

class _InputScreenState extends State<InputScreen> {
  // Form controllers
  final _formKey = GlobalKey<FormState>(); //final- 화면이 닫힐때까지 유지, 제네릭으로 형태만 설정
  final _nameController = TextEditingController(); //화면에 써진 값 활용위해 컨트롤러 필요
  final _wateringFrequencyController = TextEditingController();
  final _notesController = TextEditingController();

  // 추가 1: 네임 필드용 포커스 노드
  final FocusNode _nameFocusNode = FocusNode();

  // 추가 2: 동적 카테고리 필드용 매니저 리스트
  final List<TextEditingController> _categoryControllers = [];
  final List<FocusNode> _categoryFocusNodes = [];

  final FocusNode _wateringFrequencyFocusNode = FocusNode();

  final FocusNode _notesFocusNode = FocusNode();

  // Form data
  String _imageUrl = '';
  List<String> _categories = [''];
  DateTime _lastWatered = DateTime.now();

  @override
  void initState() {
    super.initState();
    //추가 3: 화면이 처음 켜질 때, 초기 카테고리 갯수만큼 매니저 생성
    for (var category in _categories) {
      _categoryControllers.add(TextEditingController(text: category));
      _categoryFocusNodes.add(FocusNode());
    }
  }

  @override
  void dispose() { //dispose 를 사용해 final 키워드 폐기
    _nameController.dispose();
    _wateringFrequencyController.dispose();
    _notesController.dispose();

    //매니저들도 화면이 닫힐 때 꼭 메모리에서 해제
    _nameFocusNode.dispose();
    for (var controller in _categoryControllers) controller.dispose();
    for (var node in _categoryFocusNodes) node.dispose();
    _wateringFrequencyFocusNode.dispose();
    _notesFocusNode.dispose();
    super.dispose(); //부모 클래스 도구들 폐기(State 클래스는 자동 정리 가능)
    
    
  }

  // Add category
  void _addCategory() {
    if (_categories.length < 5) {
      setState(() {
        _categories.add('');
        _categoryControllers.add(TextEditingController());
        _categoryFocusNodes.add(FocusNode());
      });
    }
  }

  // Remove category
  void _removeCategory(int index) {
    if (_categories.length > 1) {
      setState(() {
        _categories.removeAt(index);
        _categoryControllers[index].dispose(); // 메모리 해제
        _categoryFocusNodes[index].dispose();
        _categoryControllers.removeAt(index);
        _categoryFocusNodes.removeAt(index);
      });
    }
  }

  // Update category
  void _updateCategory(int index, String value) {
    setState(() {
      _categories[index] = value;
    });
  }

  // Handle submit
  void _handleSubmit() async { //필터링및 가공 역할
    if (_formKey.currentState!.validate()) { //폼 안에 있는 모든 입력창에 validater실행 ->데이터 검사
      final today = _lastWatered.toIso8601String().split('T')[0]; //깔끔한 글자

      final cleanCategories = _categories
        .map((cat) => cat.trim())          // 각 카테고리 앞뒤 공백 제거
        .where((cat) => cat.isNotEmpty)     // 비어있는 문자열은 제외
        .toSet()                           // 중복된 값 자동 제거 
        .toList();                         // 다시 리스트로 변환
      
      final newPlant = Plant(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        imageUrl: _imageUrl.isEmpty 
            ? 'assets/images/home_gardening.jpg'
            : _imageUrl,
        name: _nameController.text.trim(),
        categories: cleanCategories,
        wateringFrequency: int.tryParse(_wateringFrequencyController.text) ?? 0,
        lastWatered: today,
        wateringHistory: [today],
        fertilizerHistory: [],
        notes: _notesController.text.trim(),
      );

      try {
      // 2. 실제 DB 저장소에 저장
      await PlantRepository.instance.insertPlant(newPlant);

      // 3. 부모 위젯에 알리고 화면 닫기 ->데이터의 화면상 효율적 업데이트를 위함
      widget.onSave(newPlant); 
      _resetForm();

      // 저장 성공 알림 (선택 사항)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${newPlant.name} 저장이 완료되었습니다!')),
      );
    } catch (e) {
      if (e.toString().contains('SQLITE_FULL')) {
          showStorageFullDialog(context); // UI 계층이므로 context 사용 가능!
        } 
      }
    }
  }

  // Reset form
  void _resetForm() {
    setState(() {
      _nameController.clear();
      _wateringFrequencyController.clear();
      _notesController.clear();
      _imageUrl = '';
      _categories = [''];
      _lastWatered = DateTime.now();
    });
  }

  // Show image URL input dialog
  Future<void> _showImageUrlDialog() async { //Future<void>- 미래에 끝나는 작업, async- 함수 안에서 기다려야 하는 작업 있다고 선언
    // 2. ImagePicker 객체 생성
    final ImagePicker picker = ImagePicker();
    try{
          // 3. 갤러리에서 이미지 선택 (비동기 작업이므로 await 사용)
      final XFile? image = await picker.pickImage( //갤러리내 사진위치정보 넘어옴
        source: ImageSource.gallery,
        maxWidth: 1000, // 성능을 위해 이미지 크기 제한 (선택사항)
        imageQuality: 85, // 용량 최적화
      );
      // 사용자가 사진을 고르지 않고 뒤로가기를 눌렀을 때는 에러가 아니므로 그냥 리턴합니다.
      if (image == null) return;
      try {
        // 4. 이미지를 골랐다면 상태 업데이트
          final String compressedPath = await compressImage(image.path);
          setState(() {
            // 이제 _imageUrl 변수에 파일의 로컬 경로가 저장됩니다.
            _imageUrl = compressedPath; 
          });
      }on FileSystemException catch (e) {
          // 용량 부족 에러 핸들링
        if (e.message.contains('No space left on device')) {
          showStorageFullDialog(context);
        } else {
          print("파일 시스템 오류: ${e.message}");
        }
      } catch (e) {
      // 그 외 저장 과정에서의 일반적인 오류
      print("이미지 처리 오류: $e");
    }
    }catch (e) {
      // 사용자가 권한을 거부했거나 기타 오류가 발생했을 때
      showPermissionRequestDialog(context);
    }
  }

  // Select date
  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _lastWatered,
      firstDate: DateTime(2026),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        _lastWatered = picked;
      });
      FocusScope.of(context).requestFocus(_notesFocusNode);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(  //스크롤 화면
      padding: const EdgeInsets.all(16), //여백 설정
      child: Form(
        key: _formKey, //_formKey를 통해 그룹안에 값들이 올바르게 채워졌는지 validate를 통해 검사 가능
        child: Column( //수직배치
          crossAxisAlignment: CrossAxisAlignment.stretch, //가로로 위젯들 꽉채워줌
          children: [
            // Image Upload Section
            _buildImageSection(),
            const SizedBox(height: 12),

            // Name
            _buildNameField(),
            const SizedBox(height: 12),

            // Categories
            ..._buildCategoryFields(),
            const SizedBox(height: 12),

            // Watering Frequency
            _buildWateringFrequencyField(),
            const SizedBox(height: 12),

            // Last Watered
            _buildLastWateredField(),
            const SizedBox(height: 12),

            // Notes
            _buildNotesField(),
            const SizedBox(height: 12),

            // Submit Button
            _buildSubmitButton(),
          ],
        ),
      ),
    );
  }

  // Image Section
  Widget _buildImageSection() {

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GestureDetector( //터치하면 작동
      onTap: _showImageUrlDialog,
    child: AspectRatio(
      aspectRatio: 1 / 1, // 👈 가로 3 : 세로 4 비율로 설정 (원하는 비율로 조정 가능)
      child: Container(
        width: double.infinity,
        // height: 160, // 👈 고정 높이는 삭제합니다.
        decoration: BoxDecoration(
          border: Border.all(
            color: theme.dividerColor,
            width: 2,
            style: BorderStyle.solid,
          ),
          borderRadius: BorderRadius.circular(12),
          color: colorScheme.onSurface.withOpacity(0.05),
        ),
        child: ClipRRect( // 테두리 밖으로 이미지가 나가지 않도록 깎아줌
          borderRadius: BorderRadius.circular(12),
          child: _imageUrl.isEmpty
            ? _buildImagePlaceholder() //사진이 없으면 아이콘화면
            : _buildImagePreview(), //사진이 있으면 사용자 등록 이미지
      ),
      ),
    ),
  );
}

  // Image Placeholder (정글 배경)
  Widget _buildImagePlaceholder() {

    final theme = Theme.of(context);
  final colorScheme = theme.colorScheme;
  final isDark = theme.brightness == Brightness.dark;

    return Stack(
      children: [
        // Background image
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.asset(
              isDark 
              ? 'assets/images/dark_jungle_1.jpg'  
              : 'assets/images/bright_jungle_1.jpg',
              fit: BoxFit.cover,
              opacity: AlwaysStoppedAnimation(isDark ? 0.5 : 0.5),
            ),
          ),
        ),
        
        // Gradient overlay
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                Colors.black.withOpacity(0.1),
                Colors.transparent,
                Colors.black.withOpacity(isDark ? 0.4 : 0.2), // 다크모드에서 아래쪽 그림자를 조금 더 진하게
                ],
              ),
            ),
          ),
        ),
        
        // Camera icon and text
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.surface.withOpacity(0.9),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.camera_alt,
                  size: 24,
                  color: colorScheme.secondary,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                color: colorScheme.surface.withOpacity(0.8),
                borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '사진을 추가하세요',
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Image Preview
  Widget _buildImagePreview() {

    final colorScheme = Theme.of(context).colorScheme;
    return Stack(
      children: [
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: _buildImageWidget(), // 이미지를 판단해서 그려주는 함수 호출
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: ElevatedButton(
            onPressed: _showImageUrlDialog,
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.surface.withOpacity(0.9),
              foregroundColor: colorScheme.onSurface,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              minimumSize: const Size(0, 32),
              elevation: 2,
            ),
            child: const Text(
              '변경',
              style: TextStyle(fontSize: 14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImageWidget() {

    final colorScheme = Theme.of(context).colorScheme;
  // 1. 이미지가 비어있을 때
  if (_imageUrl.isEmpty) {
    return Container(
      color: colorScheme.surface,
      child: Icon(Icons.image, size: 48, color: colorScheme.onSurface.withOpacity(0.3)),
    );
  }

  // 2. 인터넷 URL일 때 (http로 시작하는 경우)
  if (_imageUrl.startsWith('http')) {
    return Image.network(
      _imageUrl,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => _errorIcon(),
    );
  }

  // 3. 갤러리에서 가져온 로컬 파일일 때
  return Image.file( //화면에 그림
    File(_imageUrl), // (갤러리내 이미지주소)String 경로를 File 객체로 변환
    fit: BoxFit.cover,
    errorBuilder: (context, error, stackTrace) => _errorIcon(),
  );
}

// 에러 시 보여줄 공통 아이콘
Widget _errorIcon() {
  final colorScheme = Theme.of(context).colorScheme;
  return Center(
    child: Icon(Icons.broken_image, size: 48, color: colorScheme.onSurface.withOpacity(0.3)),
  );
}

  // Name Field
  Widget _buildNameField() {

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return TextFormField(
      controller: _nameController,
      focusNode: _nameFocusNode, // 포커스 노드 연결
      decoration: InputDecoration(
        hintText: '이름',
        prefixIcon: Icon(
          Icons.local_florist,
          size: 20,
          color: colorScheme.onSurface.withOpacity(0.5),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: theme.dividerColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: theme.dividerColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        filled: true,
        fillColor: colorScheme.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return '이름을 입력해주세요';
        }
        return null;
      },
      onFieldSubmitted: (_) {
        if (_categoryFocusNodes.isNotEmpty) {
          FocusScope.of(context).requestFocus(_categoryFocusNodes[0]);
        }
      },
    );
  }

  // Category Fields
  List<Widget> _buildCategoryFields() {

      final theme = Theme.of(context);
      final colorScheme = theme.colorScheme;

    return _categories.asMap().entries.map((entry) {
      final index = entry.key;
      final category = entry.value;
      
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Expanded(
              child: TextFormField(
                // initialValue는 삭제하고 매니저들을 연결합니다!
                controller: _categoryControllers[index],
                focusNode: _categoryFocusNodes[index],

                textInputAction: TextInputAction.next,

                onFieldSubmitted: (_) {
                  if (index < _categories.length - 1) {
                    // 다음 카테고리가 있으면 다음 카테고리로
                    FocusScope.of(context).requestFocus(_categoryFocusNodes[index + 1]);
                  } else {
                    // 마지막 카테고리면 물 주기 필드로 슝!
                    FocusScope.of(context).requestFocus(_wateringFrequencyFocusNode);
                  }
                },
                decoration: InputDecoration(
                  hintText: '카테고리',
                  prefixIcon: Icon(
                    Icons.local_offer,
                    size: 20,
                    color: colorScheme.onSurface.withOpacity(0.5),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: theme.dividerColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: theme.dividerColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: colorScheme.primary, width: 2),
                  ),
                  filled: true,
                  fillColor: colorScheme.surface,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                // 데이터 보관만 하고 setState는 호출하지 않습니다! (키보드 유지)
                onChanged: (value) {
                  _categories[index] = value;
                },
              ),
            ),
            const SizedBox(width: 8),
            
            // Add/Remove Button
            if (index == 0)
              _buildCategoryButton(
                icon: Icons.add,
                onPressed: _categories.length >= 5 ? null : _addCategory,
              )
            else
              _buildCategoryButton(
                icon: Icons.remove,
                onPressed: () => _removeCategory(index),
              ),
          ],
        ),
      );
    }).toList();
  }

  // Category Add/Remove Button
  Widget _buildCategoryButton({
    required IconData icon,
    VoidCallback? onPressed,
  }) {

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return SizedBox(
      width: 40,
      height: 48,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          side: BorderSide(color: theme.dividerColor),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Icon(
          icon,
          size: 20,
          color: onPressed == null 
            ? colorScheme.onSurface.withOpacity(0.3) 
            : colorScheme.onSurface.withOpacity(0.7),
        ),
      ),
    );
  }

  // Watering Frequency Field
  Widget _buildWateringFrequencyField() {

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return TextFormField(
      controller: _wateringFrequencyController,
      focusNode: _wateringFrequencyFocusNode,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        hintText: '물 주기 (일)',
        prefixIcon: Icon(
          Icons.water_drop,
          size: 20,
          color: colorScheme.onSurface.withOpacity(0.5),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: theme.dividerColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: theme.dividerColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        filled: true,
        fillColor: colorScheme.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return '물 주기를 입력해주세요';
        }
        final number = int.tryParse(value);
        if (number == null || number < 1) {
          return '1 이상의 숫자를 입력해주세요';
        }
        return null;
      },
      // 하단 버튼을 '완료(Done)' 모양으로 변경
      textInputAction: TextInputAction.done,
      
      // '완료' 버튼을 눌렀을 때 모든 포커스를 해제하여 키보드를 닫음
      onFieldSubmitted: (_) {
        FocusScope.of(context).unfocus(); 
      },
    );
  }

  // Last Watered Field
  Widget _buildLastWateredField() {

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return InkWell(
      onTap: _selectDate,
      child: InputDecorator(
        decoration: InputDecoration(
          //hintText: '최근 물 준 날짜',
          labelText: '최근 물 준 날짜',
          prefixIcon: Icon(
            Icons.calendar_today,
            size: 20,
            color: colorScheme.onSurface.withOpacity(0.5),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: theme.dividerColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: theme.dividerColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: colorScheme.primary, width: 2),
          ),
          filled: true,
          fillColor: colorScheme.surface,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
        child: Text(
          '${_lastWatered.year}년 ${_lastWatered.month}월 ${_lastWatered.day}일',
          style: TextStyle(
            fontSize: 16,
            color: colorScheme.onSurface,
          ),
        ),
      ),
    );
  }

  // Notes Field
  Widget _buildNotesField() {

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return TextFormField(
      controller: _notesController,
      focusNode: _notesFocusNode,
      maxLines: 3,
      style: TextStyle(color: colorScheme.onSurface),
      decoration: InputDecoration(
        hintText: '특이사항',
        prefixIcon: Padding(
          padding: EdgeInsets.only(bottom: 48),
          child: Icon(
            Icons.description,
            size: 20,
            color: colorScheme.onSurface.withOpacity(0.5),
          ),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: theme.dividerColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: theme.dividerColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        filled: true,
        fillColor: colorScheme.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }

  // Submit Button
  Widget _buildSubmitButton() {

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

  return SafeArea(
    // 하단 여백만 확보하기 위해 나머지는 false로 설정
    top: false,
    left: false,
    right: false,
    bottom: true, 
    child: Padding(
      // 버튼 주변에 최소한의 여백 추가
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: SizedBox(
        width: double.infinity, // 버튼이 가로로 꽉 차게 설정
        child: ElevatedButton(
          onPressed: _handleSubmit,
          style: ElevatedButton.styleFrom(
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
            padding: const EdgeInsets.symmetric(vertical: 16), // 클릭 영역 확대를 위해 패딩 조정
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            elevation: 0,
          ),
          child: const Text(
            '저장하기',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    ),
  );
}
}
