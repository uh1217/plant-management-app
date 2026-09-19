import 'package:flutter_test/flutter_test.dart';
import 'package:plantapp_p/domain/entities/care_item.dart';
import 'package:plantapp_p/domain/entities/care_record.dart';
import 'package:plantapp_p/domain/sync_last_care_date.dart';

CareItem _item({
  required String id,
  required bool includeWatering,
}) =>
    CareItem(
      id: id,
      type: CareItemType.fertilizer,
      name: '비료',
      color: 0,
      cycleMemo: '',
      includeWatering: includeWatering,
      createdAt: '2026-09-01',
    );

void main() {
  group('SyncLastCareDate.wateringHistory', () {
    test('최근 기록을 새 날짜로 바꾸고 이후 기록은 삭제한다', () {
      expect(
        SyncLastCareDate.wateringHistory(
          history: ['2026-09-01', '2026-09-10', '2026-09-18'],
          newDate: '2026-09-12',
        ),
        ['2026-09-01', '2026-09-10', '2026-09-12'],
      );
    });

    test('날짜를 앞으로 옮기면 최근 기록만 바뀐다', () {
      expect(
        SyncLastCareDate.wateringHistory(
          history: ['2026-09-01', '2026-09-10', '2026-09-15'],
          newDate: '2026-09-18',
        ),
        ['2026-09-01', '2026-09-10', '2026-09-18'],
      );
    });

    test('새 날짜가 이미 있으면 중복을 제거한다', () {
      expect(
        SyncLastCareDate.wateringHistory(
          history: ['2026-09-01', '2026-09-10', '2026-09-18'],
          newDate: '2026-09-10',
        ),
        ['2026-09-01', '2026-09-10'],
      );
    });

    test('빈 목록이면 새 날짜 한 건을 넣는다', () {
      expect(
        SyncLastCareDate.wateringHistory(history: [], newDate: '2026-09-12'),
        ['2026-09-12'],
      );
    });
  });

  group('SyncLastCareDate.careHistory', () {
    test('같은 날이고 물과 함께 주기면 최근 기록 날짜를 바꾼다', () {
      final items = [_item(id: 'f1', includeWatering: true)];
      final history = [
        const CareRecord(date: '2026-09-01', itemId: 'f1', name: '비료', cycle: ''),
        const CareRecord(date: '2026-09-18', itemId: 'f1', name: '비료', cycle: ''),
      ];
      final result = SyncLastCareDate.careHistory(
        history: history,
        oldDate: '2026-09-18',
        newDate: '2026-09-12',
        careItems: items,
      );
      expect(result.map((r) => r.date).toList(), ['2026-09-01', '2026-09-12']);
    });

    test('날짜가 달라도 바꾸지 않는다', () {
      final items = [_item(id: 'f1', includeWatering: true)];
      final history = [
        const CareRecord(date: '2026-09-10', itemId: 'f1', name: '비료', cycle: ''),
      ];
      final result = SyncLastCareDate.careHistory(
        history: history,
        oldDate: '2026-09-18',
        newDate: '2026-09-12',
        careItems: items,
      );
      expect(result.single.date, '2026-09-10');
    });

    test('물과 함께 주기가 꺼져 있으면 바꾸지 않는다', () {
      final items = [_item(id: 'f1', includeWatering: false)];
      final history = [
        const CareRecord(date: '2026-09-18', itemId: 'f1', name: '비료', cycle: ''),
      ];
      final result = SyncLastCareDate.careHistory(
        history: history,
        oldDate: '2026-09-18',
        newDate: '2026-09-12',
        careItems: items,
      );
      expect(result.single.date, '2026-09-18');
    });
  });
}
