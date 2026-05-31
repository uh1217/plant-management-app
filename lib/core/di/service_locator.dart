import 'package:plantapp_p/Data/datasources/auth_remote_datasource.dart';
import 'package:plantapp_p/Data/datasources/plant_remote_datasource.dart';
import 'package:plantapp_p/Data/repositories_impl/auth_repository_impl.dart';
import 'package:plantapp_p/Data/repositories_impl/plant_repository_impl.dart';
import 'package:plantapp_p/domain/repositories/auth_repository.dart';
import 'package:plantapp_p/domain/repositories/plant_repository.dart';
import 'package:plantapp_p/domain/usecases/delete_plant_usecase.dart';
import 'package:plantapp_p/domain/usecases/fertilize_plant_usecase.dart';
import 'package:plantapp_p/domain/usecases/get_plants_usecase.dart';
import 'package:plantapp_p/domain/usecases/save_plant_usecase.dart';
import 'package:plantapp_p/domain/usecases/sign_in_with_google_usecase.dart';
import 'package:plantapp_p/domain/usecases/sign_out_usecase.dart';
import 'package:plantapp_p/domain/usecases/water_plant_usecase.dart';
import 'package:plantapp_p/presentation/viewmodels/home_view_model.dart';
import 'package:plantapp_p/presentation/viewmodels/login_view_model.dart';

/// 앱 전역 의존성 수동 주입 -> 화면 부를 때 마다 유스케이스 등 선언 방지
class ServiceLocator {
  ServiceLocator._(); //private 부여
  static final ServiceLocator instance = ServiceLocator._(); //싱글톤 패턴 부여

  late final PlantRepository plantRepository; //선언시점이 아닌 init() 메서드 호출 시점에 메모리 할당
  late final AuthRepository authRepository;

  late final GetPlantsUseCase getPlantsUseCase;
  late final SavePlantUseCase savePlantUseCase;
  late final DeletePlantUseCase deletePlantUseCase;
  late final WaterPlantUseCase waterPlantUseCase;
  late final FertilizePlantUseCase fertilizePlantUseCase;
  late final SignInWithGoogleUseCase signInWithGoogleUseCase;
  late final SignOutUseCase signOutUseCase;

  // @init 전에 각 유스케이스 실행 되면 안됨 -> late 변수들 ServiceLocator.instance.init() 전에 값 할당 안되서 에러
  void init() {
    //데이터 소스 생성
    final plantDs = PlantRemoteDataSource();
    final authDs = AuthRemoteDataSource();

    //RepositoryImpl 에 주입
    plantRepository = PlantRepositoryImpl(plantDs);
    authRepository = AuthRepositoryImpl(authDs);

    //usecases에 주입
    getPlantsUseCase = GetPlantsUseCase(plantRepository);
    savePlantUseCase = SavePlantUseCase(plantRepository);
    deletePlantUseCase = DeletePlantUseCase(plantRepository);
    waterPlantUseCase = WaterPlantUseCase(plantRepository);
    fertilizePlantUseCase = FertilizePlantUseCase(plantRepository);
    signInWithGoogleUseCase = SignInWithGoogleUseCase(authRepository);
    signOutUseCase = SignOutUseCase(authRepository);
  }

  //viewmodel은 화면이 닫힐 때 함께 메모리에서 해제되야 함
  HomeViewModel createHomeViewModel() => HomeViewModel(
        getPlants: getPlantsUseCase,
        savePlant: savePlantUseCase,
        deletePlant: deletePlantUseCase,
        waterPlant: waterPlantUseCase,
        fertilizePlant: fertilizePlantUseCase,
        signOut: signOutUseCase,
      );

  LoginViewModel createLoginViewModel() => LoginViewModel(
        signInWithGoogle: signInWithGoogleUseCase,
      );
}
