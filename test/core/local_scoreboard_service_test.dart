import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/core/local_scoreboard_service.dart';
import 'package:roy_casual_kit/core/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  tearDown(Get.reset);

  late StorageService storage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = StorageService(await SharedPreferences.getInstance());
    Get.put(storage, permanent: true);
  });

  group('LocalScoreboardService: submitScore validation', () {
    test('rejects empty/blank playerLabel before mutation', () {
      final service = LocalScoreboardService();

      expect(() => service.submitScore('', 10), throwsArgumentError);
      expect(() => service.submitScore('   ', 10), throwsArgumentError);
      expect(service.topN(10), isEmpty);
    });

    test('rejects negative score before mutation', () {
      final service = LocalScoreboardService();

      expect(() => service.submitScore('Roy', -1), throwsArgumentError);
      expect(service.topN(10), isEmpty);
    });

    test('score 0 hợp lệ (không throw)', () {
      final service = LocalScoreboardService();

      expect(() => service.submitScore('Roy', 0), returnsNormally);
      expect(service.topN(10), hasLength(1));
    });

    test('constructor throw assert khi capacity <= 0', () {
      expect(() => LocalScoreboardService(capacity: 0), throwsA(anything));
      expect(() => LocalScoreboardService(capacity: -1), throwsA(anything));
    });
  });

  group('LocalScoreboardService: topN sắp xếp/xếp hạng', () {
    test('topN rỗng khi chưa submit gì, không throw', () {
      final service = LocalScoreboardService();
      expect(service.topN(10), isEmpty);
    });

    test('topN(n) <= 0 trả về rỗng, không throw', () {
      final service = LocalScoreboardService();
      service.submitScore('Roy', 10);

      expect(service.topN(0), isEmpty);
      expect(service.topN(-5), isEmpty);
    });

    test('sắp xếp giảm dần theo score, rank đúng 1-based', () {
      final service = LocalScoreboardService();
      service.submitScore('Low', 10);
      service.submitScore('High', 100);
      service.submitScore('Mid', 50);

      final top = service.topN(10);
      expect(top.map((e) => e.name).toList(), ['High', 'Mid', 'Low']);
      expect(top.map((e) => e.rank).toList(), [1, 2, 3]);
    });

    test('score format qua fmtNum (dấu phân cách hàng nghìn)', () {
      final service = LocalScoreboardService();
      service.submitScore('Roy', 12345);

      expect(service.topN(1).single.score, '12,345');
    });

    test('topN(n) lớn hơn số entry hiện có chỉ trả về đúng số entry đang có', () {
      final service = LocalScoreboardService();
      service.submitScore('A', 1);
      service.submitScore('B', 2);

      expect(service.topN(10), hasLength(2));
    });

    test('cùng điểm số: submit trước xếp hạng cao hơn (tie-break theo thứ tự submit)', () {
      final service = LocalScoreboardService();
      service.submitScore('First', 50);
      service.submitScore('Second', 50);

      final top = service.topN(2);
      expect(top[0].name, 'First');
      expect(top[1].name, 'Second');
    });

    test('cùng player được submit nhiều lần — không dedupe, mỗi lần là 1 dòng', () {
      final service = LocalScoreboardService();
      service.submitScore('Roy', 10);
      service.submitScore('Roy', 20);

      final top = service.topN(10);
      expect(top, hasLength(2));
      expect(top.map((e) => e.name).toList(), ['Roy', 'Roy']);
    });
  });

  group('LocalScoreboardService: capacity cap', () {
    test('vượt cap: điểm thấp nhất bị cắt bớt, không xuất hiện trong topN', () {
      final service = LocalScoreboardService(capacity: 3);
      service.submitScore('A', 40);
      service.submitScore('B', 30);
      service.submitScore('C', 20);
      service.submitScore('D', 10);

      final top = service.topN(10);
      expect(top, hasLength(3));
      expect(top.map((e) => e.name).toList(), ['A', 'B', 'C']);
    });

    test(
      'submit điểm thấp hơn mọi entry đã có trong cap đầy: bị loại ngay, không lọt vào topN',
      () {
        final service = LocalScoreboardService(capacity: 2);
        service.submitScore('High', 100);
        service.submitScore('Mid', 50);

        service.submitScore('Low', 1);

        final top = service.topN(10);
        expect(top.map((e) => e.name).toList(), ['High', 'Mid']);
      },
    );
  });

  group('LocalScoreboardService: persist/corrupt', () {
    test('drops corrupt entries instead of crashing hydration', () async {
      await storage.setString(
        'local_scoreboard_v1',
        '{"entries":['
        '{"playerLabel":"good","score":10,"sequence":1},'
        '{"playerLabel":"","score":10,"sequence":1},'
        '{"playerLabel":"negativeScore","score":-1,"sequence":1},'
        '{"playerLabel":"wrongScoreType","score":"10","sequence":1},'
        '{"playerLabel":"wrongSequenceType","score":10,"sequence":"x"},'
        '"not a map"'
        '],"schemaVersion":1}',
      );
      final service = LocalScoreboardService();

      final top = service.topN(10);
      expect(top.map((e) => e.name).toList(), ['good']);
    });

    test('reload từ instance mới đọc lại đúng danh sách đã lưu', () async {
      final service = LocalScoreboardService();
      service.submitScore('Roy', 100);
      service.submitScore('Sam', 50);

      await service.debugPendingSaves;

      final reloaded = LocalScoreboardService();
      final top = reloaded.topN(10);
      expect(top.map((e) => e.name).toList(), ['Roy', 'Sam']);
    });

    test(
      'burst nhiều submitScore liên tiếp không await giữa các lần vẫn ghi đúng toàn bộ xuống disk',
      () async {
        final service = LocalScoreboardService();

        for (var i = 0; i < 10; i++) {
          service.submitScore('Player$i', i);
        }

        await service.debugPendingSaves;

        final reloaded = LocalScoreboardService();
        expect(reloaded.topN(20), hasLength(10));
      },
    );
  });
}
