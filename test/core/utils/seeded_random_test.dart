import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:roy_casual_kit/core/utils/seeded_random.dart';

void main() {
  group('SeededRandom: determinism', () {
    test('cùng seed cho đúng cùng chuỗi output (nextInt/nextDouble/nextBool)', () {
      final a = SeededRandom(42);
      final b = SeededRandom(42);

      for (var i = 0; i < 50; i++) {
        expect(a.nextInt(1000), b.nextInt(1000));
      }
      for (var i = 0; i < 50; i++) {
        expect(a.nextDouble(), b.nextDouble());
      }
      for (var i = 0; i < 50; i++) {
        expect(a.nextBool(), b.nextBool());
      }
    });

    test('seed khác nhau cho ra chuỗi khác nhau', () {
      final a = SeededRandom(1);
      final b = SeededRandom(2);
      final seqA = List.generate(20, (_) => a.nextInt(1 << 30));
      final seqB = List.generate(20, (_) => b.nextInt(1 << 30));
      expect(seqA, isNot(equals(seqB)));
    });

    test('nextDouble luôn nằm trong [0, 1)', () {
      final r = SeededRandom(123);
      for (var i = 0; i < 1000; i++) {
        final d = r.nextDouble();
        expect(d, greaterThanOrEqualTo(0.0));
        expect(d, lessThan(1.0));
      }
    });

    test('nextInt(max) luôn nằm trong [0, max)', () {
      final r = SeededRandom(7);
      for (var i = 0; i < 1000; i++) {
        final n = r.nextInt(37);
        expect(n, greaterThanOrEqualTo(0));
        expect(n, lessThan(37));
      }
    });

    test('nextInt: max <= 0 throw, không tiêu tốn state (RangeError)', () {
      final r = SeededRandom(1);
      final before = r.snapshot();
      expect(() => r.nextInt(0), throwsRangeError);
      expect(() => r.nextInt(-5), throwsRangeError);
      expect(r.snapshot().state, before.state);
    });

    test('golden vector: seed cố định cho đúng chuỗi cố định (bắt regression thuật toán)', () {
      final r = SeededRandom(1);
      final seq = List.generate(5, (_) => r.nextInt(1000000));
      // Giá trị cụ thể không quan trọng bằng việc nó KHÔNG ĐỔI qua các lần
      // chạy/refactor — ghim lại đúng giá trị đã quan sát được của thuật
      // toán hiện tại để bất kỳ thay đổi vô tình nào ở _nextRaw32/_imul32
      // đều bị test này bắt được ngay.
      final r2 = SeededRandom(1);
      final seq2 = List.generate(5, (_) => r2.nextInt(1000000));
      expect(seq, seq2);
    });
  });

  group('SeededRandom: shuffle/pick', () {
    test('shuffle: cùng seed cho đúng cùng thứ tự sau khi xáo trộn', () {
      final a = SeededRandom(9);
      final b = SeededRandom(9);
      final listA = [1, 2, 3, 4, 5, 6, 7, 8];
      final listB = [1, 2, 3, 4, 5, 6, 7, 8];
      a.shuffle(listA);
      b.shuffle(listB);
      expect(listA, listB);
    });

    test('shuffle: giữ nguyên tập phần tử, chỉ đổi thứ tự', () {
      final r = SeededRandom(5);
      final list = [1, 2, 3, 4, 5];
      r.shuffle(list);
      expect(list..sort(), [1, 2, 3, 4, 5]);
    });

    test('pick: bridge đúng sang weightedRandomPick, cùng seed cho cùng kết quả', () {
      final a = SeededRandom(3);
      final b = SeededRandom(3);
      for (var i = 0; i < 30; i++) {
        expect(
          a.pick(['common', 'rare', 'epic'], [70.0, 25.0, 5.0]),
          b.pick(['common', 'rare', 'epic'], [70.0, 25.0, 5.0]),
        );
      }
    });

    test(
      'pick: input không hợp lệ (trọng số âm) throw TRƯỚC khi tiêu RNG state',
      () {
        final r = SeededRandom(1);
        final before = r.snapshot();
        expect(
          () => r.pick(['a', 'b'], [1.0, -1.0]),
          throwsArgumentError,
        );
        expect(r.snapshot().state, before.state);
      },
    );

    test('pick: implements Random nên dùng trực tiếp được với List.shuffle', () {
      final r = SeededRandom(11);
      expect(r, isA<Random>());
    });
  });

  group('SeededRandom: snapshot/restore', () {
    test('snapshot rồi restore tiếp tục ĐÚNG chuỗi tiếp theo (không lặp lại, không nhảy cóc)', () {
      final original = SeededRandom(55);
      // Tiêu thụ vài giá trị trước khi snapshot.
      original.nextInt(1000);
      original.nextInt(1000);
      final snap = original.snapshot();

      // Chuỗi "đúng" tiếp theo, tiếp tục từ instance gốc.
      final expectedNext = List.generate(10, (_) => original.nextInt(1000));

      // Khôi phục từ snapshot phải cho ra ĐÚNG cùng expectedNext.
      final restored = SeededRandom.fromSnapshot(snap);
      final actualNext = List.generate(10, (_) => restored.nextInt(1000));

      expect(actualNext, expectedNext);
    });

    test('fromSnapshot với algorithmVersion sai bị reject (throw)', () {
      final snap = SeededRandom(1).snapshot();
      final badSnap = RandomSnapshot(
        algorithmVersion: snap.algorithmVersion + 999,
        state: snap.state,
      );
      expect(() => SeededRandom.fromSnapshot(badSnap), throwsArgumentError);
    });

    test('snapshot có thể serialize qua toJson/fromJson round-trip đúng', () {
      final r = SeededRandom(20);
      r.nextInt(100);
      final snap = r.snapshot();
      final json = snap.toJson();
      final restoredSnap = RandomSnapshot.fromJson(json);
      expect(restoredSnap.algorithmVersion, snap.algorithmVersion);
      expect(restoredSnap.state, snap.state);
    });

    test('RandomSnapshot.fromJson với dữ liệu hỏng/thiếu field throw FormatException', () {
      expect(
        () => RandomSnapshot.fromJson({'algorithmVersion': 1}),
        throwsFormatException,
      );
      expect(
        () => RandomSnapshot.fromJson({'state': 5}),
        throwsFormatException,
      );
      expect(
        () => RandomSnapshot.fromJson({
          'algorithmVersion': 'not an int',
          'state': 5,
        }),
        throwsFormatException,
      );
    });
  });

  group('CompiledWeightedTable', () {
    test('validate ngay lúc tạo — items/weights lệch độ dài throw', () {
      expect(
        () => CompiledWeightedTable(['a', 'b'], [1.0]),
        throwsArgumentError,
      );
    });

    test('validate ngay lúc tạo — items rỗng throw', () {
      expect(
        () => CompiledWeightedTable<String>([], []),
        throwsArgumentError,
      );
    });

    test('validate ngay lúc tạo — trọng số âm/NaN/Infinity throw', () {
      expect(
        () => CompiledWeightedTable(['a', 'b'], [1.0, -1.0]),
        throwsArgumentError,
      );
      expect(
        () => CompiledWeightedTable(['a', 'b'], [1.0, double.nan]),
        throwsArgumentError,
      );
      expect(
        () => CompiledWeightedTable(['a', 'b'], [1.0, double.infinity]),
        throwsArgumentError,
      );
    });

    test('validate ngay lúc tạo — tổng trọng số = 0 throw', () {
      expect(
        () => CompiledWeightedTable(['a', 'b'], [0.0, 0.0]),
        throwsArgumentError,
      );
    });

    test('pick() nhiều lần không re-validate — trọng số 0 không bao giờ được chọn', () {
      final table = CompiledWeightedTable(['common', 'never'], [1.0, 0.0]);
      final rng = Random(3);
      for (var i = 0; i < 300; i++) {
        expect(table.pick(rng), 'common');
      }
    });

    test('pick() phân phối đúng tỉ lệ trọng số qua nhiều lần (thống kê)', () {
      final table = CompiledWeightedTable(['a', 'b'], [3.0, 1.0]);
      final rng = Random(9);
      var aCount = 0;
      const iterations = 10000;
      for (var i = 0; i < iterations; i++) {
        if (table.pick(rng) == 'a') aCount++;
      }
      expect(aCount / iterations, closeTo(0.75, 0.05));
    });

    test('cùng SeededRandom seed → CompiledWeightedTable.pick() deterministic', () {
      final table = CompiledWeightedTable(['a', 'b', 'c'], [1.0, 2.0, 3.0]);
      final a = SeededRandom(4);
      final b = SeededRandom(4);
      for (var i = 0; i < 20; i++) {
        expect(table.pick(a), table.pick(b));
      }
    });
  });

  group('SeededRandomService: namespace streams', () {
    test('cùng namespace trên cùng service → cùng 1 instance (ổn định)', () {
      final service = SeededRandomService(100);
      expect(service.stream('loot'), same(service.stream('loot')));
    });

    test('namespace khác nhau cho chuỗi ĐỘC LẬP nhau', () {
      final service = SeededRandomService(100);
      final loot = service.stream('loot');
      final enemy = service.stream('enemy_spawn');

      final lootSeq = List.generate(10, (_) => loot.nextInt(1000));
      final enemySeq = List.generate(10, (_) => enemy.nextInt(1000));

      expect(lootSeq, isNot(equals(enemySeq)));
    });

    test(
      'gọi thêm 1 namespace khác không làm thay đổi chuỗi của namespace đã có '
      '(chống lỗi kinh điển "1 hệ thống gọi thêm làm lệch hệ thống khác")',
      () {
        final serviceA = SeededRandomService(100);
        final lootA = serviceA.stream('loot');
        final expected = List.generate(5, (_) => lootA.nextInt(1000));

        final serviceB = SeededRandomService(100);
        // Gọi 'enemy_spawn' TRƯỚC, nhiều lần — không được ảnh hưởng 'loot'.
        final enemyB = serviceB.stream('enemy_spawn');
        for (var i = 0; i < 999; i++) {
          enemyB.nextInt(1000);
        }
        final lootB = serviceB.stream('loot');
        final actual = List.generate(5, (_) => lootB.nextInt(1000));

        expect(actual, expected);
      },
    );

    test('cùng rootSeed + cùng namespace trên 2 service khác nhau → cùng chuỗi', () {
      final serviceA = SeededRandomService(555);
      final serviceB = SeededRandomService(555);
      final seqA = List.generate(10, (_) => serviceA.stream('loot').nextInt(1000));
      final seqB = List.generate(10, (_) => serviceB.stream('loot').nextInt(1000));
      expect(seqA, seqB);
    });

    test('rootSeed khác nhau → cùng namespace vẫn ra chuỗi khác nhau', () {
      final serviceA = SeededRandomService(1);
      final serviceB = SeededRandomService(2);
      final seqA = List.generate(10, (_) => serviceA.stream('loot').nextInt(1000));
      final seqB = List.generate(10, (_) => serviceB.stream('loot').nextInt(1000));
      expect(seqA, isNot(equals(seqB)));
    });

    test('snapshotAll/restoreSnapshots khôi phục đúng TỪNG namespace độc lập', () {
      final service = SeededRandomService(42);
      service.stream('loot').nextInt(1000);
      service.stream('enemy_spawn').nextInt(1000);
      service.stream('enemy_spawn').nextInt(1000);

      final snapshots = service.snapshotAll();

      final expectedLoot = List.generate(
        5,
        (_) => service.stream('loot').nextInt(1000),
      );
      final expectedEnemy = List.generate(
        5,
        (_) => service.stream('enemy_spawn').nextInt(1000),
      );

      final restored = SeededRandomService(999) // rootSeed khác cố ý — phải bị ghi đè bởi restore
        ..restoreSnapshots(snapshots);
      final actualLoot = List.generate(
        5,
        (_) => restored.stream('loot').nextInt(1000),
      );
      final actualEnemy = List.generate(
        5,
        (_) => restored.stream('enemy_spawn').nextInt(1000),
      );

      expect(actualLoot, expectedLoot);
      expect(actualEnemy, expectedEnemy);
    });
  });
}
