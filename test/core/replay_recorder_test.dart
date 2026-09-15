import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/core/replay_recorder.dart';
import 'package:roy_casual_kit/core/utils/seeded_random.dart';

void main() {
  tearDown(Get.reset);

  group('ReplayEvent', () {
    test('toJson/fromJson round-trip đúng', () {
      const event = ReplayEvent(
        offsetMs: 1234,
        type: 'tap',
        payload: {'x': 10, 'y': 20},
      );
      final restored = ReplayEvent.fromJson(event.toJson());
      expect(restored.offsetMs, 1234);
      expect(restored.type, 'tap');
      expect(restored.payload, {'x': 10, 'y': 20});
    });

    test('fromJson với dữ liệu hỏng throw FormatException', () {
      expect(
        () => ReplayEvent.fromJson({'offsetMs': 'not an int', 'type': 'tap', 'payload': {}}),
        throwsFormatException,
      );
      expect(
        () => ReplayEvent.fromJson({'offsetMs': 1, 'payload': {}}),
        throwsFormatException,
      );
      expect(
        () => ReplayEvent.fromJson({'offsetMs': 1, 'type': 'tap', 'payload': 'not a map'}),
        throwsFormatException,
      );
    });
  });

  group('ReplayCapsule: schema/tamper/corrupt', () {
    ReplayCapsule sample() => const ReplayCapsule(
      seed: 42,
      appVersion: '1.0.0',
      events: [
        ReplayEvent(offsetMs: 0, type: 'tap', payload: {'id': 1}),
        ReplayEvent(offsetMs: 100, type: 'tap', payload: {'id': 2}),
      ],
    );

    test('toJson/fromJsonUnsigned round-trip đúng (không ký)', () {
      final capsule = sample();
      final restored = ReplayCapsule.fromJsonUnsigned(capsule.toJson());
      expect(restored, isNotNull);
      expect(restored!.seed, 42);
      expect(restored.appVersion, '1.0.0');
      expect(restored.events.length, 2);
      expect(restored.events[1].payload, {'id': 2});
    });

    test('fromJsonUnsigned: schemaVersion khác bị từ chối an toàn (trả null, không throw)', () {
      final json = sample().toJson();
      json['schemaVersion'] = 999;
      expect(ReplayCapsule.fromJsonUnsigned(json), isNull);
    });

    test('fromJsonUnsigned: field thiếu/sai kiểu bị từ chối an toàn (trả null)', () {
      expect(ReplayCapsule.fromJsonUnsigned({}), isNull);
      expect(
        ReplayCapsule.fromJsonUnsigned({
          'schemaVersion': ReplayCapsule.schemaVersion,
          'seed': 'not an int',
          'appVersion': '1.0.0',
          'events': [],
        }),
        isNull,
      );
      expect(
        ReplayCapsule.fromJsonUnsigned({
          'schemaVersion': ReplayCapsule.schemaVersion,
          'seed': 1,
          'appVersion': '1.0.0',
          'events': 'not a list',
        }),
        isNull,
      );
    });

    test('exportSigned/importSigned round-trip đúng với đúng secret', () {
      final capsule = sample();
      final signed = capsule.exportSigned('s3cr3t');
      final restored = ReplayCapsule.importSigned(signed, 's3cr3t');
      expect(restored, isNotNull);
      expect(restored!.seed, 42);
      expect(restored.events.length, 2);
    });

    test('importSigned: sai secret bị từ chối an toàn (trả null, không throw)', () {
      final signed = sample().exportSigned('s3cr3t');
      expect(
        () => ReplayCapsule.importSigned(signed, 'wrong-secret'),
        returnsNormally,
      );
      expect(ReplayCapsule.importSigned(signed, 'wrong-secret'), isNull);
    });

    test('importSigned: dữ liệu bị chỉnh sửa (tamper) sau khi ký bị từ chối', () {
      final signed = sample().exportSigned('s3cr3t');
      final tampered = {...signed, 'seed': 999999};
      expect(ReplayCapsule.importSigned(tampered, 's3cr3t'), isNull);
    });

    test('importSigned: JSON thiếu checksum (chưa từng được ký) bị từ chối', () {
      final json = sample().toJson();
      expect(ReplayCapsule.importSigned(json, 's3cr3t'), isNull);
    });
  });

  group('ReplayRecorder: bounded ring buffer', () {
    test('maybe trả về null khi chưa Get.put', () {
      expect(ReplayRecorder.maybe, isNull);
    });

    test('maybe trả về đúng instance khi đã đăng ký', () {
      final recorder = ReplayRecorder();
      Get.put(recorder, permanent: true);
      expect(ReplayRecorder.maybe, same(recorder));
    });

    test('chưa start() thì isRecording false, record() không throw (no-op)', () {
      final recorder = ReplayRecorder();
      expect(recorder.isRecording, isFalse);
      expect(() => recorder.record('tap', {'x': 1}), returnsNormally);
      expect(recorder.eventCount, 0);
    });

    test('start() rồi record() đúng số lượng event, đúng thứ tự', () {
      final recorder = ReplayRecorder(capacity: 10);
      recorder.start(seed: 7);
      expect(recorder.isRecording, isTrue);
      recorder.record('a', {});
      recorder.record('b', {});
      recorder.record('c', {});
      expect(recorder.eventCount, 3);

      final capsule = recorder.buildCapsule(appVersion: '1.0.0');
      expect(capsule.seed, 7);
      expect(capsule.events.map((e) => e.type).toList(), ['a', 'b', 'c']);
    });

    test('stop() rồi record() tiếp không thêm event nữa (no-op)', () {
      final recorder = ReplayRecorder(capacity: 10);
      recorder.start(seed: 1);
      recorder.record('a', {});
      recorder.stop();
      expect(recorder.isRecording, isFalse);
      recorder.record('b', {});
      expect(recorder.eventCount, 1);
    });

    test(
      'vượt capacity: event CŨ NHẤT bị loại bỏ, giữ đúng N sự kiện MỚI NHẤT theo đúng thứ tự',
      () {
        final recorder = ReplayRecorder(capacity: 3);
        recorder.start(seed: 1);
        for (var i = 0; i < 7; i++) {
          recorder.record('event$i', {'i': i});
        }
        expect(recorder.eventCount, 3);
        final capsule = recorder.buildCapsule(appVersion: '1.0.0');
        // Chỉ giữ 3 cái cuối: event4, event5, event6.
        expect(
          capsule.events.map((e) => e.type).toList(),
          ['event4', 'event5', 'event6'],
        );
      },
    );

    test('start() lại reset đúng — không còn event của lần ghi trước', () {
      final recorder = ReplayRecorder(capacity: 10);
      recorder.start(seed: 1);
      recorder.record('old', {});
      recorder.start(seed: 2); // ghi đè, bắt đầu phiên mới
      expect(recorder.eventCount, 0);
      recorder.record('new', {});
      final capsule = recorder.buildCapsule(appVersion: '1.0.0');
      expect(capsule.seed, 2);
      expect(capsule.events.map((e) => e.type).toList(), ['new']);
    });

    test('offsetMs của mỗi event không giảm qua thời gian (đơn điệu tăng)', () async {
      final recorder = ReplayRecorder(capacity: 10);
      recorder.start(seed: 1);
      recorder.record('a', {});
      await Future<void>.delayed(const Duration(milliseconds: 5));
      recorder.record('b', {});
      final capsule = recorder.buildCapsule(appVersion: '1.0.0');
      expect(
        capsule.events[1].offsetMs,
        greaterThanOrEqualTo(capsule.events[0].offsetMs),
      );
    });
  });

  group('findFirstDivergence', () {
    test('2 danh sách giống hệt nhau → null (không phân kỳ)', () {
      expect(findFirstDivergence([1, 2, 3], [1, 2, 3]), isNull);
    });

    test('phân kỳ ở giữa → báo đúng index + giá trị mong đợi/thực tế', () {
      final d = findFirstDivergence(['a', 'b', 'c'], ['a', 'X', 'c']);
      expect(d, isNotNull);
      expect(d!.index, 1);
      expect(d.expected, 'b');
      expect(d.actual, 'X');
    });

    test('độ dài khác nhau (actual ngắn hơn) → báo đúng vị trí đầu tiên bị thiếu', () {
      final d = findFirstDivergence(['a', 'b', 'c'], ['a', 'b']);
      expect(d, isNotNull);
      expect(d!.index, 2);
      expect(d.expected, 'c');
      expect(d.actual, isNull);
    });

    test('danh sách rỗng cả 2 bên → null', () {
      expect(findFirstDivergence(<Object?>[], <Object?>[]), isNull);
    });
  });

  group('replayCapsule', () {
    int handleSpin(ReplayEvent event, SeededRandomService rng) =>
        rng.stream('wheel_spin').nextInt(event.payload['segments']! as int);

    // 3 outcome "thật" của handleSpin trên seed 99 — tính trực tiếp từ 1
    // SeededRandomService độc lập, KHÔNG đoán/hardcode giá trị, để không
    // tự khoá test vào chi tiết thuật toán RNG.
    List<int> recordRealSpins() {
      final rng = SeededRandomService(99);
      return List.generate(3, (_) => rng.stream('wheel_spin').nextInt(6));
    }

    ReplayCapsule wheelSpinCapsule(List<int> recorded) => ReplayCapsule(
      seed: 99,
      appVersion: '1.0.0',
      events: [
        for (final outcome in recorded)
          ReplayEvent(
            offsetMs: 0,
            type: 'spin',
            payload: {'segments': 6, 'expectedOutcome': outcome},
          ),
      ],
    );

    test('cùng seed, cùng handler → replay khớp y hệt (không phân kỳ)', () {
      final capsule = wheelSpinCapsule(recordRealSpins());
      expect(replayCapsule(capsule, handleSpin), isNull);
    });

    test('handler khác (bug logic mới) → báo đúng điểm phân kỳ đầu tiên', () {
      final recorded = recordRealSpins();
      final capsule = wheelSpinCapsule(recorded);
      // Handler "sai" cố ý: luôn lệch +1 (mod 6) so với RNG thật — chắc
      // chắn khác outcome gốc ở MỌI event, mô phỏng 1 bug logic thật.
      final divergence = replayCapsule(
        capsule,
        (event, rng) => (rng.stream('wheel_spin').nextInt(6) + 1) % 6,
      );
      expect(divergence, isNotNull);
      expect(divergence!.index, 0);
      expect(divergence.expected, recorded[0]);
      expect(divergence.actual, (recorded[0] + 1) % 6);
    });

    test(
      'event không có expectedOutcome vẫn được replay (giữ đúng RNG cho các event sau) nhưng không tính vào divergence check',
      () {
        const capsule = ReplayCapsule(
          seed: 1,
          appVersion: '1.0.0',
          events: [
            ReplayEvent(offsetMs: 0, type: 'noop', payload: {}),
            ReplayEvent(
              offsetMs: 10,
              type: 'roll',
              payload: {'expectedOutcome': -1},
            ),
          ],
        );
        var callCount = 0;
        final divergence = replayCapsule(capsule, (event, rng) {
          callCount++;
          return -1;
        });
        expect(callCount, 2); // cả 2 event đều được handler gọi
        expect(divergence, isNull); // chỉ event có expectedOutcome bị check
      },
    );

    test(
      'seed của capsule quyết định RNG dùng khi replay, không phải seed nào khác',
      () {
        int spin(ReplayEvent e, SeededRandomService rng) =>
            rng.stream('wheel_spin').nextInt(1 << 30);

        // Outcome "đúng" ghi lại từ 1 phiên chạy thật với seed 7.
        final expectedOutcome = spin(
          const ReplayEvent(offsetMs: 0, type: 'spin', payload: {}),
          SeededRandomService(7),
        );
        final capsule = ReplayCapsule(
          seed: 7,
          appVersion: '1.0.0',
          events: [
            ReplayEvent(
              offsetMs: 0,
              type: 'spin',
              payload: {'expectedOutcome': expectedOutcome},
            ),
          ],
        );

        // Replay đúng seed 7 (bên trong capsule) → khớp.
        expect(replayCapsule(capsule, spin), isNull);

        // Cùng expectedOutcome nhưng seed capsule đổi thành 8 → RNG khác,
        // đa số trường hợp phân kỳ ngay (đây là hành vi cốt lõi cần kiểm
        // chứng: replayCapsule PHẢI dùng seed của capsule, không phải seed
        // nào recorded ngoài).
        final divergence = replayCapsule(
          ReplayCapsule(seed: 8, appVersion: '1.0.0', events: capsule.events),
          spin,
        );
        expect(divergence, isNotNull);
      },
    );
  });

  group('Performance', () {
    test(
      'record() ở tần suất cao (giả lập nhiều frame gameplay liên tiếp) vẫn nhanh — O(1)/lần, không chậm dần theo số lần gọi',
      () {
        final recorder = ReplayRecorder(capacity: 500);
        recorder.start(seed: 1);

        // Đo 2 lô liên tiếp cùng kích thước — nếu record() vô tình có chi
        // phí tăng theo eventCount tổng (ví dụ do quét lại buffer), lô sau
        // sẽ chậm hơn lô trước rõ rệt.
        const batchSize = 20000;
        final firstBatch = Stopwatch()..start();
        for (var i = 0; i < batchSize; i++) {
          recorder.record('tap', {'i': i});
        }
        firstBatch.stop();

        final secondBatch = Stopwatch()..start();
        for (var i = 0; i < batchSize; i++) {
          recorder.record('tap', {'i': i});
        }
        secondBatch.stop();

        // Buffer luôn bị chặn ở capacity — không phình vô hạn theo số lần
        // record() được gọi.
        expect(recorder.eventCount, 500);
        // Lô sau không được chậm hơn đáng kể so với lô trước (cho phép
        // biên độ nhiễu rộng — đây là smoke check chống hồi quy O(n²), chứ
        // không phải benchmark chính xác micro-giây).
        expect(
          secondBatch.elapsedMicroseconds,
          lessThan(firstBatch.elapsedMicroseconds * 5 + 50000),
        );
      },
    );
  });
}
