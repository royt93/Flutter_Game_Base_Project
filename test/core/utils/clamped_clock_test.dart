import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/core/storage_service.dart';
import 'package:roy_casual_kit/core/utils/clamped_clock.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// `clamped_clock.dart` ([[X22]]) — lớp chống gian lận đồng hồ dùng chung cho
/// pet idle và Raid Boss. Trước file này nó chỉ được phủ **gián tiếp** qua
/// `raid_boss_controller_test`.
///
/// [[T5]] cho rằng không viết được test trực tiếp vì `Get.put` trong helper
/// `async` mất đăng ký qua async gap. Đo lại: **không tái hiện được** — xem
/// phần "Kết luận" trong file task. Nghi phạm còn lại là hiệu ứng kernel cũ mà
/// chính T5 đã cảnh báo (lần chạy đầu sau khi sửa test cho kết quả khác lần
/// hai).
Future<void> _boot([Map<String, Object> prefs = const {}]) async {
  SharedPreferences.setMockInitialValues(prefs);
  final store = await SharedPreferences.getInstance();
  Get.put(StorageService(store), permanent: true);
}

int get _realDay => DateTime.now().toUtc().millisecondsSinceEpoch ~/ 86400000;
int get _realMs => DateTime.now().toUtc().millisecondsSinceEpoch;

void main() {
  tearDown(() => setDebugTimeOffsetMs(0));

  setUp(() => clockRewindBlockedCount = 0);
  tearDown(Get.reset);

  group('máy sạch', () {
    test('ngày: trả về ngày thật và ghi lại mốc', () async {
      await _boot();

      expect(todayEpochDayClamped(), _realDay);
      expect(
        StorageService.to.getInt(StorageKeys.maxEpochDaySeen),
        _realDay,
        reason: 'không ghi mốc thì lần sau chỉnh lùi vẫn ăn',
      );
    });

    test('mili-giây: trả về giờ thật và ghi lại mốc', () async {
      await _boot();

      final before = _realMs;
      final got = nowMsClamped();

      expect(got, greaterThanOrEqualTo(before));
      expect(got, lessThanOrEqualTo(_realMs));
      expect(StorageService.to.getInt(StorageKeys.maxMsSeen), got);
    });
  });

  group('chống chỉnh đồng hồ LÙI', () {
    test(
      'ngày: mốc ở tương lai thì giữ nguyên, không lùi về ngày thật',
      () async {
        // Đây đúng là bước "chỉnh về" của vòng farm: tiến 30 ngày, nhận thưởng,
        // rồi chỉnh lại. Sau khi kẹp, bước chỉnh lại vô tác dụng.
        final future = _realDay + 30;
        await _boot({StorageKeys.maxEpochDaySeen: future});

        expect(todayEpochDayClamped(), future);
        expect(
          StorageService.to.getInt(StorageKeys.maxEpochDaySeen),
          future,
          reason: 'mốc không được hạ xuống',
        );
      },
    );

    test('mili-giây: mốc ở tương lai thì giữ nguyên', () async {
      final future = _realMs + 86400000;
      await _boot({StorageKeys.maxMsSeen: future});

      expect(nowMsClamped(), future);
      expect(StorageService.to.getInt(StorageKeys.maxMsSeen), future);
    });

    test('lùi đúng 1 ngày cũng không ăn', () async {
      final tomorrow = _realDay + 1;
      await _boot({StorageKeys.maxEpochDaySeen: tomorrow});

      expect(todayEpochDayClamped(), tomorrow);
    });

    test('gọi lặp lại không bao giờ giảm', () async {
      await _boot({StorageKeys.maxEpochDaySeen: _realDay + 5});

      var last = todayEpochDayClamped();
      for (var i = 0; i < 5; i++) {
        final now = todayEpochDayClamped();
        expect(now, greaterThanOrEqualTo(last));
        last = now;
      }
    });
  });

  group('mốc ở quá khứ', () {
    test('ngày: tiến lên ngày thật và cập nhật mốc', () async {
      await _boot({StorageKeys.maxEpochDaySeen: _realDay - 10});

      expect(todayEpochDayClamped(), _realDay);
      expect(StorageService.to.getInt(StorageKeys.maxEpochDaySeen), _realDay);
    });

    test('mili-giây: tiến lên giờ thật', () async {
      final past = _realMs - 86400000;
      await _boot({StorageKeys.maxMsSeen: past});

      expect(nowMsClamped(), greaterThan(past));
    });

    test('mốc bằng đúng hiện tại: không đổi, không ghi thừa', () async {
      // `current > maxSeen` là so sánh CHẶT — bằng nhau thì đi nhánh trả mốc,
      // không ghi lại. Đổi thành `>=` là mỗi lần gọi một lần ghi đĩa.
      await _boot({StorageKeys.maxEpochDaySeen: _realDay});
      final store = StorageService.to;
      final writes = store.platformWrites;

      expect(todayEpochDayClamped(), _realDay);
      expect(
        store.platformWrites,
        writes,
        reason: 'đọc-only khi không có gì thay đổi',
      );
    });
  });

  group('hai đồng hồ độc lập', () {
    test('dùng key riêng, không đè nhau', () async {
      await _boot();

      todayEpochDayClamped();
      nowMsClamped();

      final store = StorageService.to;
      expect(store.getInt(StorageKeys.maxEpochDaySeen), _realDay);
      expect(store.getInt(StorageKeys.maxMsSeen), greaterThan(_realDay));
    });

    test('kẹp đồng hồ ngày KHÔNG kẹp đồng hồ mili-giây', () async {
      await _boot({StorageKeys.maxEpochDaySeen: _realDay + 100});

      expect(todayEpochDayClamped(), _realDay + 100);
      expect(
        nowMsClamped(),
        lessThanOrEqualTo(_realMs),
        reason: 'hai mốc riêng biệt; gộp chung là một chỗ hỏng kéo cả hai',
      );
    });
  });

  group('giới hạn đã biết', () {
    test('nhảy TIẾN một chiều KHÔNG bị chặn — và thành vĩnh viễn', () async {
      // Không phải lỗ hổng bỏ sót mà là giới hạn có chủ ý, ghi trong doc của
      // `clamped_clock.dart`: client không có nguồn thời gian tin cậy.
      //
      // Ca này tồn tại để ai đó định "vá nốt" thì thấy hệ quả: mốc tương lai
      // dính luôn, nên đừng áp lớp kẹp cho `isWeekendEvent` — ở lại thứ Bảy
      // vĩnh viễn còn tệ hơn.
      final jumped = _realDay + 365;
      await _boot({StorageKeys.maxEpochDaySeen: jumped});

      expect(todayEpochDayClamped(), jumped);
      expect(
        todayEpochDayClamped(),
        jumped,
        reason: 'gọi lại vẫn ở tương lai — trạng thái này không tự hồi',
      );
    });
  });

  group('đếm số lần chặn tua ngược (clockRewindBlockedCount)', () {
    test('máy sạch, đồng hồ tiến bình thường -> không tăng đếm', () async {
      await _boot();

      todayEpochDayClamped();
      nowMsClamped();

      expect(clockRewindBlockedCount, 0);
    });

    test('mốc ở tương lai (bị chặn) -> đếm tăng 1', () async {
      final future = _realDay + 30;
      await _boot({StorageKeys.maxEpochDaySeen: future});

      todayEpochDayClamped();

      expect(clockRewindBlockedCount, 1);
    });

    test('mili-giây bị chặn -> đếm tăng 1', () async {
      final future = _realMs + 86400000;
      await _boot({StorageKeys.maxMsSeen: future});

      nowMsClamped();

      expect(clockRewindBlockedCount, 1);
    });

    test('gọi lặp lại khi bị chặn -> đếm tăng theo từng lần gọi', () async {
      await _boot({StorageKeys.maxEpochDaySeen: _realDay + 5});

      todayEpochDayClamped();
      todayEpochDayClamped();
      todayEpochDayClamped();

      expect(clockRewindBlockedCount, 3);
    });

    test('mốc ở quá khứ (tiến lên bình thường) -> không tăng đếm', () async {
      await _boot({StorageKeys.maxEpochDaySeen: _realDay - 10});

      todayEpochDayClamped();

      expect(clockRewindBlockedCount, 0);
    });

    test(
      // BUG-48: gọi lại nhiều lần TRONG CÙNG 1 ngày (current == maxSeen mọi
      // lần) không phải rewind — trước fix, nhánh else tăng đếm mỗi lần gọi
      // dù đồng hồ không hề bị tua lùi, làm sai lệch số liệu QA/anti-cheat.
      'ngày: current == maxSeen (gọi lại cùng ngày) -> KHÔNG tăng đếm',
      () async {
        await _boot({StorageKeys.maxEpochDaySeen: _realDay});

        todayEpochDayClamped();
        todayEpochDayClamped();
        todayEpochDayClamped();

        expect(clockRewindBlockedCount, 0);
      },
    );

  });

  group('save hỏng', () {
    test('mốc sai kiểu -> coi như chưa có, không ném', () async {
      // [[X28]]: getter type-safe trả default thay vì ném.
      await _boot({StorageKeys.maxEpochDaySeen: 'khong-phai-so'});

      expect(todayEpochDayClamped(), _realDay);
    });

    test('mốc âm -> tiến lên ngày thật', () async {
      await _boot({StorageKeys.maxEpochDaySeen: -999});

      expect(todayEpochDayClamped(), _realDay);
    });
  });

  group('FEAT-93: setDebugTimeOffsetMs (Time Travel tab)', () {
    test('mặc định offset=0, không ảnh hưởng gì', () async {
      await _boot();

      expect(debugTimeOffsetMs, 0);
      expect(nowMsClamped(), closeTo(_realMs, 2000));
    });

    test('set offset +24h -> nowMsClamped() nhảy tới đúng tương lai', () async {
      await _boot();
      final oneDayMs = const Duration(days: 1).inMilliseconds;

      setDebugTimeOffsetMs(oneDayMs);

      expect(debugTimeOffsetMs, oneDayMs);
      expect(nowMsClamped(), closeTo(_realMs + oneDayMs, 2000));
    });

    test(
      'set offset +7 ngày -> todayEpochDayClamped() cũng nhảy đúng, phản '
      'ánh nhất quán cả 2 hàm',
      () async {
        await _boot();
        final sevenDaysMs = const Duration(days: 7).inMilliseconds;

        setDebugTimeOffsetMs(sevenDaysMs);

        expect(
          todayEpochDayClamped(),
          _realDay + 7,
          reason:
              'Daily Login/Quest/Season Event đều đọc todayEpochDayClamped, '
              'phải cùng nhảy tương lai như nowMsClamped',
        );
      },
    );

    test(
      'set về 0 -> quay lại đúng ngay lúc gọi (KHÔNG lùi mốc watermark đã '
      'ratchet lên, giống hệt hành vi vặn đồng hồ thật lùi lại)',
      () async {
        await _boot();
        setDebugTimeOffsetMs(Duration(hours: 2).inMilliseconds);
        final jumped = nowMsClamped(); // ratchet maxMsSeen lên tương lai.

        setDebugTimeOffsetMs(0);

        expect(debugTimeOffsetMs, 0);
        // watermark đã ratchet lên `jumped` — đọc lại NGAY LẬP TỨC (không
        // có thời gian thật trôi qua) phải clamp ở watermark đó, không
        // lùi xuống thời gian thật hiện tại.
        expect(nowMsClamped(), greaterThanOrEqualTo(jumped));
      },
    );
  });
}
