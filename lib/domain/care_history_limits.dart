/// 케어 기록 배열은 다음 쓰기 때 최신 N개로 자른다. 기존 문서는 읽기만으로는 줄이지 않는다.
abstract final class CareHistoryLimits {
  static const watering = 3;
  static const fertilizer = 5;
  static const pesticide = 3;

  static List<T> trim<T>(List<T> history, int limit) =>
      history.length > limit ? history.sublist(history.length - limit) : history;
}
