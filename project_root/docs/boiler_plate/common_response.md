# Common Response Structure (Result Pattern)

## 1. 개요 (Overview)
* **패턴:** Result Pattern (Sealed Class 기반)
* **목적:** 모든 데이터 요청(Firebase, REST API, Local DB)의 응답 형식을 통일하여 UI 계층의 복잡도를 줄이고 에러 처리를 강제함.

## 2. 구조 정의 (Core Structure)
* **Result<T> (Sealed Class):**
  * `Success<T>`: 요청 성공 시 실제 데이터(`data`)를 담는 상자.
  * `Failure<T>`: 요청 실패 시 예외 객체(`error`)와 사용자 메시지(`message`)를 담는 상자.

## 3. Cursor/AI 개발 원칙 (Core Rules)
1. **타입 안전성:** 모든 Service 및 Repository 메서드는 날것의 데이터를 반환하지 않고, 반드시 `Future<Result<T>>` 형식을 반환해야 한다.
2. **패턴 매칭 강제:** UI에서 데이터를 처리할 때는 `if (data == null)` 같은 방식이 아닌, Dart 3의 `switch` 문을 활용한 패턴 매칭으로 성공과 실패 케이스를 모두 구현해야 한다.
3. **매핑 규칙:** - 외부 API(JSON) 데이터는 각 도메인 모델(Plant, Weather 등)로 먼저 변환(Parsing)한다.
   - 변환 성공 시 `Success`에 담고, 파싱 에러나 네트워크 에러 발생 시 `Failure`에 담는다.

## 4. 적용 예시 (Reference)
` ` `dart
// 데이터를 가져오는 표준 방식
Future<Result<List<Plant>>> getPlants() async {
  try {
    // 1. 데이터 가져오기 및 파싱
    final data = await api.fetch(); 
    // 2. 성공 상자에 담기
    return Success(data); 
  } catch (e) {
    // 3. 에러 발생 시 실패 상자에 담기
    return Failure(error: e, message: "불러오기 실패"); 
  }
}
` ` `