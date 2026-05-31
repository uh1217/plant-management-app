# Folder Structure
이 프로젝트는 아래의 폴더 구조를 엄격히 따른다.

lib/
 ┣ core/                # 에러 처리, 공통 유틸, DI(의존성 주입) 설정
 ┣ data/
 ┃ ┣ datasources/       # Firebase Firestore, 외부 API 통신 (Remote)
 ┃ ┣ models/            # Entity를 JSON/Firestore로 변환하는 DTO 모델
 ┃ ┗ repositories_impl/ # domain/repositories 인터페이스의 실제 구현체
 ┣ domain/              # domain폴더를 import 할떄 대문자(Domain) 이 아닌 소문자(domain) 으로 명시한다.
 ┃ ┣ entities/          # 앱 핵심 데이터 객체 (Firebase 의존성 완전 배제)
 ┃ ┣ repositories/      # 데이터 접근 설계도 (Interface)
 ┃ ┗ usecases/          # 단일 행동(기능) 단위 (예: WaterPlantUseCase)
 ┗ presentation/
   ┣ views/             # 화면, UI 위젯
   ┗ viewmodels/        # 상태 관리 (상태 홀더 및 UseCase 호출)
