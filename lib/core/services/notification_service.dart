import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;

/// 물주기 알람을 예약·취소하는 싱글톤 서비스.
/// main()에서 init()을 한 번 호출한 뒤 사용한다.
class NotificationService {
  static final NotificationService instance = NotificationService._internal();
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  // 알림 식별자 — 같은 ID로 재등록하면 기존 알람이 덮어씌워짐
  static const int _notifId = 1;
  // Android 8+ 필수 채널 ID / 이름
  static const String _channelId = 'plant_watering';
  static const String _channelName = '물주기 알림';

  /// 앱 시작 시 딱 한 번 호출.
  /// 타임존 데이터 초기화 → 알림 플러그인 세팅 → 알림 권한 요청 순으로 실행.
  Future<void> init() async {
    // 타임존 전체 데이터 로드 후 로컬 타임존을 서울(UTC+9)로 고정.
    // 추후 위치 권한 연동 시 사용자의 실제 좌표로 조회한 타임존 ID로 교체 가능.
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Seoul'));

    // 알림 아이콘으로 앱 런처 아이콘(@mipmap/ic_launcher) 사용
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // flutter_local_notifications 20.x: initialize는 named parameter 방식
    await _plugin.initialize(
      settings: const InitializationSettings(android: androidSettings),
    );

    // Android 13+(API 33+) 기기에서 알림 표시 권한을 사용자에게 요청.
    // 앱 최초 실행 시 허용/거부 팝업이 뜨며, 거부해도 앱은 정상 동작한다.
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  /// 매일 [hour24]시 [minute]분에 "오늘 식물에 물 줄 시간이에요!" 알림을 반복 예약.
  /// 이미 예약된 알람이 있으면 같은 ID(_notifId)로 덮어씌운다.
  Future<void> scheduleWateringAlarm(int hour24, int minute) async {
    final androidImpl =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    // Android 12+(API 31+)에서 정확한 알람 권한 여부 확인
    final canExact =
        await androidImpl?.canScheduleExactNotifications() ?? false;

    // 권한 없으면 시스템 설정 화면으로 안내해 사용자가 직접 허용하도록 요청
    if (!canExact) {
      await androidImpl?.requestExactAlarmsPermission();
    }

    // 권한 있으면 정확한 시각에 발사, 없으면 몇 분 오차를 허용하는 근사치 알람으로 폴백
    // 식물 관리 알람은 몇 분 오차가 있어도 실용적으로 충분히 동작한다.
    final scheduleMode = canExact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;

    // flutter_local_notifications 20.x: zonedSchedule은 named parameter 방식
    await _plugin.zonedSchedule(
      id: _notifId,
      title: '식물 관리 앱',
      body: '오늘 식물에 물 줄 시간이에요! 💧',
      scheduledDate: _nextAlarmTime(hour24, minute),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: '매일 설정한 시간에 물주기 알림을 보냅니다.',
          importance: Importance.high, // 소리 + 화면 상단 헤드업 팝업
          priority: Priority.high,     // 알림 목록 상단 우선순위 표시
          // sound, enableVibration, playSound는 미설정 시 기기 기본값 사용
        ),
      ),
      androidScheduleMode: scheduleMode,
      // 날짜는 무시하고 매일 같은 시:분에 반복 발사
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  /// 예약된 물주기 알람을 취소한다.
  Future<void> cancelWateringAlarm() async {
    // flutter_local_notifications 20.x: cancel도 named parameter 방식
    await _plugin.cancel(id: _notifId);
  }

  // ── 오늘 [hour]:[minute]이 이미 지났으면 내일 같은 시각을 반환한다. ──────────
  tz.TZDateTime _nextAlarmTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
