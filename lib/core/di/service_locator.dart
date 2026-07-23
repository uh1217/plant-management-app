import 'package:plantapp_p/data/datasources/auth_remote_datasource.dart';
import 'package:plantapp_p/data/datasources/city_datasource.dart';
import 'package:plantapp_p/data/datasources/gemini_datasource.dart';
import 'package:plantapp_p/data/datasources/plant_remote_datasource.dart';
import 'package:plantapp_p/data/datasources/weather_remote_datasource.dart';
import 'package:plantapp_p/data/repositories_impl/auth_repository_impl.dart';
import 'package:plantapp_p/data/repositories_impl/chat_repository_impl.dart';
import 'package:plantapp_p/data/repositories_impl/plant_repository_impl.dart';
import 'package:plantapp_p/data/repositories_impl/weather_repository_impl.dart';
import 'package:plantapp_p/core/services/gemini_service.dart';
import 'package:plantapp_p/core/services/weather_recommendation_service.dart';
import 'package:plantapp_p/domain/repositories/auth_repository.dart';
import 'package:plantapp_p/domain/repositories/plant_repository.dart';
import 'package:plantapp_p/domain/repositories/chat_repository.dart';
import 'package:plantapp_p/domain/repositories/weather_repository.dart';
import 'package:plantapp_p/domain/usecases/delete_plant_usecase.dart';
import 'package:plantapp_p/domain/usecases/fertilize_plant_usecase.dart';
import 'package:plantapp_p/domain/usecases/pesticide_plant_usecase.dart';
import 'package:plantapp_p/domain/usecases/get_plants_usecase.dart';
import 'package:plantapp_p/domain/usecases/save_plant_usecase.dart';
import 'package:plantapp_p/domain/usecases/sign_in_with_google_usecase.dart';
import 'package:plantapp_p/domain/usecases/sign_out_usecase.dart';
import 'package:plantapp_p/domain/usecases/water_plant_usecase.dart';
import 'package:plantapp_p/domain/usecases/send_message_usecase.dart';
import 'package:plantapp_p/domain/usecases/get_weather_recommendation_usecase.dart';
import 'package:plantapp_p/domain/usecases/get_gallery_photos_usecase.dart';
import 'package:plantapp_p/domain/usecases/add_gallery_photo_usecase.dart';
import 'package:plantapp_p/presentation/viewmodels/home_view_model.dart';
import 'package:plantapp_p/presentation/viewmodels/login_view_model.dart';
import 'package:plantapp_p/presentation/viewmodels/chat_view_model.dart';

/// 앱 전역 의존성 수동 주입 -> 화면 부를 때 마다 유스케이스 등 선언 방지
class ServiceLocator {
  ServiceLocator._(); //private 부여
  static final ServiceLocator instance = ServiceLocator._(); //싱글톤 패턴 부여

  late final PlantRepository plantRepository;
  late final AuthRepository authRepository;
  late final ChatRepository chatRepository;
  late final WeatherRepository weatherRepository;
  late final GeminiService geminiService;
  late final WeatherRecommendationService weatherRecommendationService;
  late final CityDataSource cityDataSource;
  late final WeatherRemoteDataSource weatherDataSource;

  late final GetPlantsUseCase getPlantsUseCase;
  late final SavePlantUseCase savePlantUseCase;
  late final DeletePlantUseCase deletePlantUseCase;
  late final WaterPlantUseCase waterPlantUseCase;
  late final FertilizePlantUseCase fertilizePlantUseCase;
  late final PesticidePlantUseCase pesticidePlantUseCase;
  late final SignInWithGoogleUseCase signInWithGoogleUseCase;
  late final SignOutUseCase signOutUseCase;
  late final SendMessageUseCase sendMessageUseCase;
  late final GetWeatherRecommendationUseCase getWeatherRecommendationUseCase;
  late final GetGalleryPhotosUseCase getGalleryPhotosUseCase;
  late final AddGalleryPhotoUseCase addGalleryPhotoUseCase;

  // @init 전에 각 유스케이스 실행 되면 안됨 -> late 변수들 ServiceLocator.instance.init() 전에 값 할당 안되서 에러
  void init() {
    // 데이터 소스 생성
    final plantDs = PlantRemoteDataSource();
    final authDs = AuthRemoteDataSource();
    cityDataSource = CityDataSource();
    weatherDataSource = WeatherRemoteDataSource();
    geminiService = GeminiService()..init(); // Firebase 초기화 이후 실행
    weatherRecommendationService = WeatherRecommendationService()..init();
    final geminiDs = GeminiDataSource(geminiService);

    // RepositoryImpl 에 주입
    plantRepository = PlantRepositoryImpl(plantDs);
    authRepository = AuthRepositoryImpl(authDs);
    chatRepository = ChatRepositoryImpl(geminiDs);
    weatherRepository = WeatherRepositoryImpl(weatherDataSource);

    // UseCases에 주입
    getPlantsUseCase = GetPlantsUseCase(plantRepository);
    savePlantUseCase = SavePlantUseCase(plantRepository);
    deletePlantUseCase = DeletePlantUseCase(plantRepository);
    waterPlantUseCase = WaterPlantUseCase(plantRepository);
    fertilizePlantUseCase = FertilizePlantUseCase(plantRepository);
    pesticidePlantUseCase = PesticidePlantUseCase(plantRepository);
    signInWithGoogleUseCase = SignInWithGoogleUseCase(authRepository);
    signOutUseCase = SignOutUseCase(authRepository);
    sendMessageUseCase = SendMessageUseCase(chatRepository);
    getWeatherRecommendationUseCase = GetWeatherRecommendationUseCase(
      city: cityDataSource,
      weather: weatherRepository,
      recommendation: weatherRecommendationService,
    );
    getGalleryPhotosUseCase = GetGalleryPhotosUseCase(plantRepository);
    addGalleryPhotoUseCase = AddGalleryPhotoUseCase(plantRepository);
  }

  // ViewModels은 화면이 닫힐 때 함께 메모리에서 해제되야 함
  HomeViewModel createHomeViewModel() => HomeViewModel(
        getPlants: getPlantsUseCase,
        savePlant: savePlantUseCase,
        deletePlant: deletePlantUseCase,
        waterPlant: waterPlantUseCase,
        fertilizePlant: fertilizePlantUseCase,
        pesticidePlant: pesticidePlantUseCase,
        signOut: signOutUseCase,
        geminiService: geminiService,
        getWeatherRecommendation: getWeatherRecommendationUseCase,
        cityDataSource: cityDataSource,
        weatherDataSource: weatherDataSource,
      );

  LoginViewModel createLoginViewModel() => LoginViewModel(
        signInWithGoogle: signInWithGoogleUseCase,
      );

  /// [uid] FirebaseAuth.currentUser!.uid - 사용자별 대화 세션과 RAG 컨텍스트 분리에 사용
  ChatViewModel createChatViewModel(String uid) => ChatViewModel(
        sendMessageUseCase: sendMessageUseCase,
        uid: uid,
      );
}
