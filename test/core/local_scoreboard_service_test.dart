import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/core/local_scoreboard_service.dart';
import 'package:roy_casual_kit/core/save_slot_manager.dart';
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

  group('ENH-85: capacity <= 0 throw ArgumentError ngay tại constructor', () {
    test('capacity: 0 throw ArgumentError', () {
      expect(() => LocalScoreboardService(capacity: 0), throwsArgumentError);
    });

    test('capacity: -1 cũng bị chặn tương tự', () {
      expect(() => LocalScoreboardService(capacity: -1), throwsArgumentError);
    });

    test(
      'validate là if/throw thường, không phải assert() — không thể bị '
      'strip ở release build (không có cách chạy dart --no-enable-asserts '
      'cho package này vì `get` kéo theo dart:ui qua package:flutter, nên '
      'chứng minh bằng cấu trúc: check chạy vô điều kiện, không nằm trong '
      'assert())',
      () {
        // Nếu implementation dùng lại `assert(...)`, test capacity: 0/-1
        // ở trên vẫn "pass" theo nghĩa throw — nhưng throw AssertionError,
        // không phải ArgumentError, nên `throwsArgumentError` phân biệt
        // đúng 2 trường hợp. Test này chỉ giữ hành vi throw đúng type
        // không bị đổi ngược lại về assert trong tương lai.
        expect(
          () => LocalScoreboardService(capacity: 0),
          throwsA(isA<ArgumentError>()),
        );
      },
    );
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

    test(
      'topN(n) lớn hơn số entry hiện có chỉ trả về đúng số entry đang có',
      () {
        final service = LocalScoreboardService();
        service.submitScore('A', 1);
        service.submitScore('B', 2);

        expect(service.topN(10), hasLength(2));
      },
    );

    test(
      'cùng điểm số: submit trước xếp hạng cao hơn (tie-break theo thứ tự submit)',
      () {
        final service = LocalScoreboardService();
        service.submitScore('First', 50);
        service.submitScore('Second', 50);

        final top = service.topN(2);
        expect(top[0].name, 'First');
        expect(top[1].name, 'Second');
      },
    );

    test(
      'cùng player được submit nhiều lần — không dedupe, mỗi lần là 1 dòng',
      () {
        final service = LocalScoreboardService();
        service.submitScore('Roy', 10);
        service.submitScore('Roy', 20);

        final top = service.topN(10);
        expect(top, hasLength(2));
        expect(top.map((e) => e.name).toList(), ['Roy', 'Roy']);
      },
    );
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

  group('IDEA-48: entriesAround', () {
    LocalScoreboardService seeded() {
      final service = LocalScoreboardService();
      // 10 người chơi, điểm giảm dần: P0=100 (hạng 1) ... P9=10 (hạng 10).
      for (var i = 0; i < 10; i++) {
        service.submitScore('P$i', 100 - i * 10);
      }
      return service;
    }

    test(
      'trả về đúng radius dòng mỗi bên + dòng của người chơi, đúng thứ tự rank',
      () {
        final service = seeded();
        // P5 ở hạng 6 (điểm 50). radius=2 -> hạng 4..8 (P3..P7).
        final around = service.entriesAround('P5', radius: 2);
        expect(around.map((e) => e.name).toList(), [
          'P3',
          'P4',
          'P5',
          'P6',
          'P7',
        ]);
        expect(around.map((e) => e.rank).toList(), [4, 5, 6, 7, 8]);
      },
    );

    test('dòng của playerLabel highlighted: true, các dòng khác false', () {
      final service = seeded();
      final around = service.entriesAround('P5', radius: 2);
      for (final entry in around) {
        expect(entry.highlighted, entry.name == 'P5');
      }
    });

    test(
      'người chơi ở hạng 1: không đủ dòng phía trên, không throw, trả về ít hơn 2*radius+1',
      () {
        final service = seeded();
        final around = service.entriesAround('P0', radius: 2);
        expect(around.map((e) => e.name).toList(), ['P0', 'P1', 'P2']);
        expect(around.first.rank, 1);
      },
    );

    test('người chơi ở hạng cuối: không đủ dòng phía dưới, không throw', () {
      final service = seeded();
      final around = service.entriesAround('P9', radius: 2);
      expect(around.map((e) => e.name).toList(), ['P7', 'P8', 'P9']);
      expect(around.last.rank, 10);
    });

    test('playerLabel không tồn tại: trả về danh sách rỗng, không throw', () {
      final service = seeded();
      expect(() => service.entriesAround('Ghost'), returnsNormally);
      expect(service.entriesAround('Ghost'), isEmpty);
    });

    test(
      'nhiều dòng cùng tên playerLabel: dùng đúng dòng có sequence lớn nhất (lần submit gần nhất)',
      () {
        final service = LocalScoreboardService();
        service.submitScore('Roy', 10); // sequence 0, hạng thấp
        service.submitScore('Other', 50); // sequence 1
        service.submitScore('Roy', 90); // sequence 2, hạng cao — lần gần nhất

        final around = service.entriesAround('Roy', radius: 1);
        // Dòng "Roy" được chọn phải là hạng 1 (điểm 90), không phải hạng 3 (điểm 10).
        final royEntry = around.firstWhere((e) => e.highlighted);
        expect(royEntry.score, '90');
        expect(royEntry.rank, 1);
      },
    );

    test('radius == 0: trả về đúng 1 dòng của chính người chơi', () {
      final service = seeded();
      final around = service.entriesAround('P5', radius: 0);
      expect(around, hasLength(1));
      expect(around.single.name, 'P5');
      expect(around.single.highlighted, isTrue);
    });

    test('radius âm: xử lý như 0, không throw, không index out of range', () {
      final service = seeded();
      expect(() => service.entriesAround('P5', radius: -3), returnsNormally);
      expect(service.entriesAround('P5', radius: -3), hasLength(1));
    });

    test('bảng rỗng (chưa submit gì): trả về danh sách rỗng, không throw', () {
      final service = LocalScoreboardService();
      expect(() => service.entriesAround('Anyone'), returnsNormally);
      expect(service.entriesAround('Anyone'), isEmpty);
    });
  });

  group('ENH-69: storageKey tuỳ chỉnh', () {
    test(
      'không truyền storageKey: hành vi/dữ liệu y hệt hiện tại, đọc đúng key cũ',
      () async {
        final service = LocalScoreboardService();
        service.submitScore('Roy', 100);
        await service.debugPendingSaves;

        expect(storage.getString('local_scoreboard_v1'), isNotNull);
      },
    );

    test(
      '2 storageKey khác nhau: 2 instance hoàn toàn độc lập, không đụng dữ liệu nhau',
      () async {
        final a = LocalScoreboardService(storageKey: 'board_a');
        final b = LocalScoreboardService(storageKey: 'board_b');

        a.submitScore('Alice', 100);
        b.submitScore('Bob', 200);
        await a.debugPendingSaves;
        await b.debugPendingSaves;

        expect(a.topN(10).map((e) => e.name), ['Alice']);
        expect(b.topN(10).map((e) => e.name), ['Bob']);
      },
    );

    test(
      'storageKey tuỳ chỉnh persist đúng qua "restart" (instance mới đọc lại đúng)',
      () async {
        final service = LocalScoreboardService(storageKey: 'board_custom');
        service.submitScore('Roy', 100);
        await service.debugPendingSaves;

        final restarted = LocalScoreboardService(storageKey: 'board_custom');
        expect(restarted.topN(10).map((e) => e.name), ['Roy']);
      },
    );

    test(
      'không đổi hành vi submitScore/topN/entriesAround/capacity hiện có khi dùng storageKey tuỳ chỉnh',
      () {
        final service = LocalScoreboardService(capacity: 2, storageKey: 'k');
        service.submitScore('A', 10);
        service.submitScore('B', 20);
        service.submitScore('C', 5); // dưới capacity, không lọt top 2

        expect(service.topN(10).map((e) => e.name), ['B', 'A']);
      },
    );

    test(
      'use-case thật: dùng SaveSlotManager.keyFor làm storageKey — mỗi slot có bảng riêng',
      () {
        final saveSlots = SaveSlotManager();
        final slotA = saveSlots.createSlot('Player A');
        final slotB = saveSlots.createSlot('Player B');

        final boardA = LocalScoreboardService(
          storageKey: saveSlots.keyFor(slotA.id, 'scoreboard'),
        );
        final boardB = LocalScoreboardService(
          storageKey: saveSlots.keyFor(slotB.id, 'scoreboard'),
        );

        boardA.submitScore('Solo', 999);

        expect(boardA.topN(10), isNotEmpty);
        expect(
          boardB.topN(10),
          isEmpty,
        ); // slot B chưa submit gì, độc lập với A
      },
    );
  });
}
