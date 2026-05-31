/// Repository·UseCase 공통 응답 래퍼
//sealed : 이 클래스는 동일한 라이브러리 내에서만 상속이 가능하도록 제한 
// 컴파일러가 Result를 상속받은 자식이 두대뿐이라는 것을 인지
sealed class Result<T> {
  const Result();
}

//가져온 데이터 this.data 에 담음
final class Success<T> extends Result<T> {
  const Success(this.data);
  final T data;
}

//에러를 Object에 담고 사용자에게 보여줄 메세지 담음
final class Failure<T> extends Result<T> {
  const Failure({required this.error, required this.message});
  final Object error;
  final String message;
}
