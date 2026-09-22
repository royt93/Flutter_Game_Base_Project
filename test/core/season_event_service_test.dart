import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/core/season_event_service.dart';
import 'package:roy_casual_kit/core/storage_service.dart';
import 'package:roy_casual_kit/core/versioned_json_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pauses `setString` until [gate] (a [Completer] the test controls)
/// resolves — the only way to genuinely hold a save "in flight" long
/// enough for a SECOND call to land while it's still running. A tight
/// synchronous loop (no real gap between calls) does NOT reproduce
/// BUG-45's race at all with the in-memory `StorageService(null)`/mocked
/// `SharedPreferences` these tests use: `await` on an already-complete
/// Future can resolve without a microtask hop, so an unawaited burst with
/// zero real I/O just runs each save to completion before the next call
/// even starts — verified empirically while building this fix.
class _GatedStorageService extends StorageService {
  _GatedStorageService(super.prefs);
  Completer<void>? gate;

  @override
  Future<void> setString(String key, String value) async {
    final g = gate;
    if (g != null) await g.future;
    return super.setString(key, value);
  }
}

/// `_realMs` anchors to the real clock at test run time — every "simulated
/// time" in this file is `_realMs + offsetMs` (offsetMs >= 0), written
/// straight to `StorageKeys.maxMsSeen`. `nowMsClamped()` returns
/// max(real time, stored watermark), so with offsetMs >= 0 the returned
/// value always equals the watermark just set — same technique as
/// `daily_login_service_test.dart`'s `_realDay`/`setDay`.
int get _realMs => DateTime.now().toUtc().millisecondsSinceEpoch;

void main() {
  tearDown(Get.reset);

  late StorageService storage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = StorageService(await SharedPreferences.getInstance());
    Get.put(storage, permanent: true);
  });

  Future<void> setNowMs(int ms) => storage.setInt(StorageKeys.maxMsSeen, ms);

  const length = Duration(hours: 2);
  const cooldown = Duration(hours: 1);

  group('SeasonEventService: validation', () {
    test('eventId rỗng/blank throw ArgumentError', () {
      final service = SeasonEventService();

      expect(
        () => service.currentWindow('', length: length, cooldown: cooldown),
        throwsArgumentError,
      );
      expect(
        () => service.currentWindow('  ', length: length, cooldown: cooldown),
        throwsArgumentError,
      );
    });

    test('length <= Duration.zero throw ArgumentError', () {
      final service = SeasonEventService();

      expect(
        () => service.currentWindow(
          'evt',
          length: Duration.zero,
          cooldown: cooldown,
        ),
        throwsArgumentError,
      );
      expect(
        () => service.currentWindow(
          'evt',
          length: const Duration(hours: -1),
          cooldown: cooldown,
        ),
        throwsArgumentError,
      );
    });

    test('cooldown âm throw ArgumentError (cooldown 0 hợp lệ)', () {
      final service = SeasonEventService();

      expect(
        () => service.currentWindow(
          'evt',
          length: length,
          cooldown: const Duration(hours: -1),
        ),
        throwsArgumentError,
      );
      expect(
        () => service.currentWindow(
          'evt',
          length: length,
          cooldown: Duration.zero,
        ),
        returnsNormally,
      );
    });
  });

  group('SeasonEventService: cùng chu kỳ trả về cùng window', () {
    test(
      'gọi lặp lại nhiều lần trong cùng chu kỳ trả về CÙNG 1 window (start/end giống hệt)',
      () async {
        await setNowMs(_realMs);
        final service = SeasonEventService();

        final first = service.currentWindow(
          'evt',
          length: length,
          cooldown: cooldown,
        );
        final second = service.currentWindow(
          'evt',
          length: length,
          cooldown: cooldown,
        );

        expect(second.start, first.start);
        expect(second.end, first.end);
      },
    );

    test(
      'window sống sót qua "restart" (instance mới đọc lại đúng anchor)',
      () async {
        await setNowMs(_realMs);
        final service = SeasonEventService();
        final first = service.currentWindow(
          'evt',
          length: length,
          cooldown: cooldown,
        );
        await service.debugPendingSaves;

        final reloaded = SeasonEventService();
        final second = reloaded.currentWindow(
          'evt',
          length: length,
          cooldown: cooldown,
        );

        expect(second.start, first.start);
        expect(second.end, first.end);
      },
    );

    test('end - start luôn đúng bằng length', () async {
      await setNowMs(_realMs);
      final service = SeasonEventService();

      final window = service.currentWindow(
        'evt',
        length: length,
        cooldown: cooldown,
      );

      expect(window.end.difference(window.start), length);
    });

    test('2 eventId khác nhau có anchor/window độc lập nhau', () async {
      await setNowMs(_realMs);
      final service = SeasonEventService();

      final a = service.currentWindow('a', length: length, cooldown: cooldown);
      // Mô phỏng "b" bắt đầu muộn hơn 30 phút.
      await setNowMs(_realMs + const Duration(minutes: 30).inMilliseconds);
      final b = service.currentWindow('b', length: length, cooldown: cooldown);

      expect(b.start, isNot(a.start));
    });
  });

  group('SeasonEventService: chuyển chu kỳ', () {
    test(
      'qua đủ length+cooldown, window MỚI xuất hiện đúng (start dịch đúng 1 chu kỳ)',
      () async {
        await setNowMs(_realMs);
        final service = SeasonEventService();
        final first = service.currentWindow(
          'evt',
          length: length,
          cooldown: cooldown,
        );

        final cycleMs = length.inMilliseconds + cooldown.inMilliseconds;
        await setNowMs(_realMs + cycleMs);

        final second = service.currentWindow(
          'evt',
          length: length,
          cooldown: cooldown,
        );

        expect(
          second.start.millisecondsSinceEpoch,
          first.start.millisecondsSinceEpoch + cycleMs,
        );
        expect(second.end.difference(second.start), length);
      },
    );

    test(
      'giữa chừng cooldown (đã qua length nhưng chưa hết cooldown) vẫn thuộc window HIỆN TẠI',
      () async {
        await setNowMs(_realMs);
        final service = SeasonEventService();
        final first = service.currentWindow(
          'evt',
          length: length,
          cooldown: cooldown,
        );

        // Ngay sau khi length kết thúc (giữa cooldown), trước khi hết cả chu kỳ.
        await setNowMs(_realMs + length.inMilliseconds + 1000);

        final duringCooldown = service.currentWindow(
          'evt',
          length: length,
          cooldown: cooldown,
        );

        expect(duringCooldown.start, first.start);
        expect(duringCooldown.end, first.end);
      },
    );

    test(
      'nhảy qua NHIỀU chu kỳ cùng lúc vẫn tính đúng chu kỳ hiện tại',
      () async {
        await setNowMs(_realMs);
        final service = SeasonEventService();
        final first = service.currentWindow(
          'evt',
          length: length,
          cooldown: cooldown,
        );

        final cycleMs = length.inMilliseconds + cooldown.inMilliseconds;
        await setNowMs(_realMs + cycleMs * 3);

        final third = service.currentWindow(
          'evt',
          length: length,
          cooldown: cooldown,
        );

        expect(
          third.start.millisecondsSinceEpoch,
          first.start.millisecondsSinceEpoch + cycleMs * 3,
        );
      },
    );
  });

  group('SeasonEventService: chống vặn đồng hồ lùi', () {
    test('vặn đồng hồ lùi KHÔNG cho reroll sang window sớm hơn', () async {
      final laterMs = _realMs + const Duration(days: 1).inMilliseconds;
      await setNowMs(laterMs);
      final service = SeasonEventService();
      final first = service.currentWindow(
        'evt',
        length: length,
        cooldown: cooldown,
      );

      // "Vặn đồng hồ lùi" — thời gian THẬT quay lại _realMs (trước
      // laterMs), nhưng watermark đã lưu vẫn giữ nguyên laterMs vì
      // nowMsClamped() không bao giờ trả về giá trị nhỏ hơn.
      final second = service.currentWindow(
        'evt',
        length: length,
        cooldown: cooldown,
      );

      expect(second.start, first.start);
      expect(second.end, first.end);
    });
  });

  group('SeasonEventService: corrupt/persist', () {
    test(
      'drops corrupt anchor entries instead of crashing hydration',
      () async {
        final goodAnchor = _realMs;
        await storage.setString(
          'season_event_anchors_v1',
          '{"good":$goodAnchor,"negative":-1,"wrongType":"1000","":1000,'
              '"schemaVersion":1}',
        );
        // "now" chỉ vài giây sau anchor — vẫn nằm trong chu kỳ đầu tiên
        // (length+cooldown = 3 tiếng), nên window.start phải bằng đúng
        // goodAnchor nếu anchor "good" được giữ nguyên (không bị coi là
        // hỏng rồi âm thầm reset).
        await setNowMs(goodAnchor + 5000);
        final service = SeasonEventService();

        final window = service.currentWindow(
          'good',
          length: length,
          cooldown: cooldown,
        );

        expect(window.start.millisecondsSinceEpoch, goodAnchor);
      },
    );
  });

  group('IDEA-52: isActive', () {
    test(
      'isActive == true khi now nằm trong [start, end) (đang trong phần length)',
      () async {
        await setNowMs(_realMs);
        final service = SeasonEventService();
        final window = service.currentWindow(
          'e',
          length: length,
          cooldown: cooldown,
        );
        expect(window.isActive, isTrue);
      },
    );

    test(
      'isActive == false khi now nằm sau end nhưng trước chu kỳ tiếp theo (đang cooldown)',
      () async {
        await setNowMs(_realMs);
        final service = SeasonEventService();
        // Thiết lập anchor TRƯỚC (lần gọi đầu tiên) — nếu không, lần gọi
        // sau sẽ tự coi thời điểm đó là anchor MỚI (luôn active tại
        // chính anchor của nó), không kiểm tra đúng ý "đang ở cooldown
        // của 1 anchor đã có từ trước".
        service.currentWindow('e', length: length, cooldown: cooldown);
        // Ngay sau khi length kết thúc, vẫn trong cooldown (chưa hết
        // length+cooldown).
        await setNowMs(_realMs + length.inMilliseconds + 1000);
        final window = service.currentWindow(
          'e',
          length: length,
          cooldown: cooldown,
        );
        expect(window.isActive, isFalse);
      },
    );

    test(
      // BUG-66: `isActive` trước fix chỉ kiểm tra `now - startMs <
      // length` — với sự kiện CHƯA bắt đầu (`now < startMs`, ví dụ anchor
      // được khôi phục từ 1 save/cloud sync đi trước đồng hồ đã kẹp của
      // chính thiết bị này), hiệu số đó âm, luôn nhỏ hơn length dương ->
      // isActive sai thành true. Seed thẳng 1 anchor TƯƠNG LAI vào đúng
      // storage key `SeasonEventService` dùng (không qua `nowMsClamped()`
      // của chính service, mô phỏng đúng "anchor tới từ nơi khác") rồi mới
      // gọi `currentWindow` với `now` ở HIỆN TẠI (trước anchor).
      'isActive == false khi now CHƯA tới startMs (sự kiện tương lai, chưa diễn ra) (BUG-66)',
      () async {
        await setNowMs(_realMs);
        const eventId = 'future_event';
        // Lệch nhỏ (< 1 chu kỳ length+cooldown) để cycleIndex tính ra đúng
        // 0 và startMs == đúng anchor đã seed, không bị vòng chu kỳ cuốn
        // sang cycle khác (dễ hiểu/verify hơn 1 offset nhiều ngày).
        final futureAnchorMs = _realMs + const Duration(minutes: 10).inMilliseconds;

        final seedStore = VersionedJsonStore<Map<String, int>>(
          storage: storage,
          key: StorageKeys.seasonEventAnchorsV1,
          schemaVersion: 1,
          toJson: (value) => value,
          fromJson: (json) => json.map(
            (key, value) => MapEntry(key, value as int),
          ),
          migrate: (fromVersion, json) => json,
        );
        await seedStore.save({eventId: futureAnchorMs});

        final service = SeasonEventService();
        final window = service.currentWindow(
          eventId,
          length: length,
          cooldown: cooldown,
        );

        expect(
          window.start.millisecondsSinceEpoch,
          futureAnchorMs,
          reason: 'anchor tương lai đã seed phải được đọc lại đúng, không bị ghi đè',
        );
        expect(window.isActive, isFalse);
      },
    );

    test(
      'gọi lại currentWindow nhiều lần trong CÙNG 1 khoảnh khắc active: isActive nhất quán true, start/end không đổi',
      () async {
        await setNowMs(_realMs);
        final service = SeasonEventService();
        final first = service.currentWindow(
          'e',
          length: length,
          cooldown: cooldown,
        );
        final second = service.currentWindow(
          'e',
          length: length,
          cooldown: cooldown,
        );
        expect(first.isActive, isTrue);
        expect(second.isActive, isTrue);
        expect(second.start, first.start);
        expect(second.end, first.end);
      },
    );

    test(
      'cooldown == Duration.zero (active liên tục): isActive luôn true',
      () async {
        await setNowMs(_realMs);
        final service = SeasonEventService();
        // Nhảy xa nhiều chu kỳ — vẫn phải luôn active vì không có cooldown.
        await setNowMs(_realMs + length.inMilliseconds * 10 + 12345);
        final window = service.currentWindow(
          'e',
          length: length,
          cooldown: Duration.zero,
        );
        expect(window.isActive, isTrue);
      },
    );

    test(
      'isActive == true ngay tại thời điểm start (biên dưới, inclusive)',
      () async {
        await setNowMs(_realMs);
        final service = SeasonEventService();
        final window = service.currentWindow(
          'e',
          length: length,
          cooldown: cooldown,
        );
        await setNowMs(window.start.millisecondsSinceEpoch);
        final atStart = service.currentWindow(
          'e',
          length: length,
          cooldown: cooldown,
        );
        expect(atStart.isActive, isTrue);
      },
    );

    test(
      'isActive == false ngay tại thời điểm end (biên trên, exclusive)',
      () async {
        await setNowMs(_realMs);
        final service = SeasonEventService();
        final window = service.currentWindow(
          'e',
          length: length,
          cooldown: cooldown,
        );
        await setNowMs(window.end.millisecondsSinceEpoch);
        final atEnd = service.currentWindow(
          'e',
          length: length,
          cooldown: cooldown,
        );
        expect(atEnd.isActive, isFalse);
      },
    );
  });

  group('ENH-71: storageKey tuỳ chỉnh', () {
    test(
      'không truyền storageKey: hành vi/dữ liệu y hệt hiện tại, đọc đúng key cũ',
      () async {
        final service = SeasonEventService();
        await setNowMs(_realMs);
        service.currentWindow('e', length: length, cooldown: cooldown);
        await service.debugPendingSaves;

        expect(storage.getString('season_event_anchors_v1'), isNotNull);
      },
    );

    test(
      '2 storageKey khác nhau: 2 instance hoàn toàn độc lập, không đụng dữ liệu nhau',
      () async {
        final a = SeasonEventService(storageKey: 'season_a');
        final b = SeasonEventService(storageKey: 'season_b');
        await setNowMs(_realMs);

        final windowA = a.currentWindow(
          'e',
          length: length,
          cooldown: cooldown,
        );
        await setNowMs(_realMs + 999999);
        final windowB = b.currentWindow(
          'e',
          length: length,
          cooldown: cooldown,
        );
        await a.debugPendingSaves;
        await b.debugPendingSaves;

        // Anchor của b được lập từ mốc thời gian khác hẳn a (do gọi lần
        // đầu ở thời điểm khác) — nếu chung key, b sẽ đọc lại đúng anchor
        // của a thay vì tự lập anchor riêng.
        expect(windowA.start.millisecondsSinceEpoch, _realMs);
        expect(windowB.start.millisecondsSinceEpoch, _realMs + 999999);
      },
    );

    test(
      'storageKey tuỳ chỉnh persist đúng qua "restart" (instance mới đọc lại đúng anchor)',
      () async {
        final service = SeasonEventService(storageKey: 'season_custom');
        await setNowMs(_realMs);
        final window = service.currentWindow(
          'e',
          length: length,
          cooldown: cooldown,
        );
        await service.debugPendingSaves;

        final restarted = SeasonEventService(storageKey: 'season_custom');
        final reloaded = restarted.currentWindow(
          'e',
          length: length,
          cooldown: cooldown,
        );
        expect(reloaded.start, window.start);
      },
    );

    test(
      'không đổi hành vi currentWindow hiện có khi dùng storageKey tuỳ chỉnh',
      () async {
        final service = SeasonEventService(storageKey: 'k');
        await setNowMs(_realMs);
        final window = service.currentWindow(
          'e',
          length: length,
          cooldown: cooldown,
        );

        expect(window.isActive, isTrue);
      },
    );
  });

  group('BUG-45: save-chain race — 2 lệnh liên tiếp chồng lấn thời gian', () {
    test(
      'currentWindow() cho event B gọi khi save của event A vẫn đang thật '
      'sự treo (Completer chưa complete): cả 2 anchor đều persist đúng, '
      'không anchor nào bị mồ côi/mất',
      () async {
        final gated = _GatedStorageService(await SharedPreferences.getInstance());
        Get.put<StorageService>(gated, permanent: true);
        await gated.setInt(StorageKeys.maxMsSeen, _realMs);
        final service = SeasonEventService();

        gated.gate = Completer<void>();
        // Anchor 'a' tạo lần đầu -> trigger _scheduleSave(), nhưng
        // setString() bị chặn bởi gate -> save này coi như đang "in
        // flight" thật sự (không phải suy đoán timing).
        final originalA = service.currentWindow(
          'event_a',
          length: length,
          cooldown: cooldown,
        );

        // Gọi tiếp cho event KHÁC trong khi save của 'a' vẫn còn treo —
        // đúng kịch bản race: `_saving` phải còn `true` lúc này.
        final originalB = service.currentWindow(
          'event_b',
          length: length,
          cooldown: cooldown,
        );

        gated.gate!.complete();
        await service.debugPendingSaves;

        // So khớp CHÍNH XÁC start/end với instance mới — không chỉ
        // `isActive` (1 anchor MỚI vô tình tạo lại do mất dữ liệu cũng
        // "active", nên không đủ để chứng minh đây là ĐÚNG anchor cũ đã
        // persist, không phải 1 anchor mồ côi bị tạo lại từ đầu).
        final restarted = SeasonEventService();
        final restoredA = restarted.currentWindow(
          'event_a',
          length: length,
          cooldown: cooldown,
        );
        final restoredB = restarted.currentWindow(
          'event_b',
          length: length,
          cooldown: cooldown,
        );
        expect(restoredA.start, originalA.start);
        expect(restoredA.end, originalA.end);
        expect(restoredB.start, originalB.start);
        expect(restoredB.end, originalB.end);
      },
    );
  });
}
