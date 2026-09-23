import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/core/replay_recorder.dart';
import 'package:roy_casual_kit/core/reproduction_capsule.dart';
import 'package:roy_casual_kit/core/save_integrity.dart';
import 'package:roy_casual_kit/core/storage_service.dart';
import 'package:roy_casual_kit/core/utils/seeded_random.dart';
import 'package:roy_casual_kit/core/utils/trusted_clock.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _secret = 'test-capsule-secret';

int _spinHandler(ReplayEvent event, SeededRandomService rng) =>
    rng.stream('wheel_spin').nextInt(event.payload['segments']! as int);

/// Records 1 real recorder session ([count] wheel-spin events on [seed])
/// through [rng] — the SAME `SeededRandomService` instance the caller then
/// passes to [ReproductionCapsule.capture], so its snapshot reflects the
/// real draws that happened during the session (matching how a live game
/// would use 1 rng instance throughout, not a throwaway one). Each
/// `expectedOutcome` is a real, independent RNG draw (not hardcoded) —
/// same convention `replay_recorder_test.dart` already uses.
ReplayRecorder _recordSession(
  SeededRandomService rng, {
  required int seed,
  int count = 3,
}) {
  final recorder = ReplayRecorder()..start(seed: seed);
  for (var i = 0; i < count; i++) {
    final outcome = rng.stream('wheel_spin').nextInt(6);
    recorder.record('spin', {'segments': 6, 'expectedOutcome': outcome});
  }
  return recorder;
}

void main() {
  tearDown(Get.reset);

  group('ReproductionCapsule.capture', () {
    test(
      'gộp đúng replay + rngSnapshots, không có clockJudgement khi '
      'trustedClock không truyền vào',
      () {
        final rng = SeededRandomService(42);
        final recorder = _recordSession(rng, seed: 42);

        final signed = ReproductionCapsule.capture(
          recorder: recorder,
          rng: rng,
          appVersion: '1.0.0',
          secret: _secret,
        );
        final decoded = verifyAndStrip(signed, _secret);

        expect(decoded['appVersion'], '1.0.0');
        expect((decoded['replay'] as Map)['seed'], 42);
        expect((decoded['replay'] as Map)['events'], hasLength(3));
        expect(
          (decoded['rngSnapshots'] as Map).containsKey('wheel_spin'),
          isTrue,
        );
        expect(decoded.containsKey('clockJudgement'), isFalse);
      },
    );

    test('gộp đúng clockJudgement khi có trustedClock đã có judgement', () async {
      SharedPreferences.setMockInitialValues({});
      Get.put(
        StorageService(await SharedPreferences.getInstance()),
        permanent: true,
      );
      var wallMs = 1000000;
      final trustedClock = TrustedClockService(
        sampleNow: () => ClockSample(wallMs: wallMs, monotonicMs: wallMs),
      );
      trustedClock.nowMsTrusted();
      wallMs += 2000; // 2s later — well within normalTolerance.
      trustedClock.nowMsTrusted();
      expect(trustedClock.lastJudgement, ClockJudgement.normal);

      final rng = SeededRandomService(7);
      final recorder = _recordSession(rng, seed: 7);

      final signed = ReproductionCapsule.capture(
        recorder: recorder,
        rng: rng,
        appVersion: '1.0.0',
        secret: _secret,
        trustedClock: trustedClock,
      );
      final decoded = verifyAndStrip(signed, _secret);

      expect(decoded['clockJudgement'], 'normal');
    });

    test(
      'redact mặc định che payload key nhạy cảm (email, deviceId, ...), '
      'giữ nguyên key khác',
      () {
        final recorder = ReplayRecorder()..start(seed: 1);
        recorder.record('login', {
          'email': 'player@example.com',
          'deviceId': 'abc-123',
          'score': 10,
        });
        final rng = SeededRandomService(1);

        final signed = ReproductionCapsule.capture(
          recorder: recorder,
          rng: rng,
          appVersion: '1.0.0',
          secret: _secret,
        );
        final decoded = verifyAndStrip(signed, _secret);
        final payload =
            ((decoded['replay'] as Map)['events'] as List).first['payload']
                as Map;

        expect(payload['email'], '<redacted>');
        expect(payload['deviceId'], '<redacted>');
        expect(payload['score'], 10);
      },
    );

    test('redactedKeys rỗng (caller tự tắt) -> KHÔNG che gì', () {
      final recorder = ReplayRecorder()..start(seed: 1);
      recorder.record('login', {'email': 'player@example.com'});
      final rng = SeededRandomService(1);

      final signed = ReproductionCapsule.capture(
        recorder: recorder,
        rng: rng,
        appVersion: '1.0.0',
        secret: _secret,
        redactedKeys: const {},
      );
      final decoded = verifyAndStrip(signed, _secret);
      final payload =
          ((decoded['replay'] as Map)['events'] as List).first['payload']
              as Map;

      expect(payload['email'], 'player@example.com');
    });

    test(
      'vượt maxBytes -> drop rngSnapshots trước (ghi vào errors/truncated), '
      'vẫn trả về capsule hợp lệ, không throw',
      () {
        final rng = SeededRandomService(5);
        final recorder = _recordSession(rng, seed: 5, count: 3);

        final signed = ReproductionCapsule.capture(
          recorder: recorder,
          rng: rng,
          appVersion: '1.0.0',
          secret: _secret,
          maxBytes: 200, // deliberately tiny — forces a drop.
        );
        final decoded = verifyAndStrip(signed, _secret);

        expect(decoded['truncated'], isTrue);
        expect(decoded.containsKey('rngSnapshots'), isFalse);
        expect(
          (decoded['errors'] as Map)['rngSnapshots'],
          contains('dropped'),
        );
        // Replay data itself (the actual point of the capsule) survives —
        // only the OPTIONAL side-channel section was dropped.
        expect((decoded['replay'] as Map)['events'], hasLength(3));
      },
    );
  });

  group('ReproductionCapsule.replay', () {
    test(
      'capture rồi replay cùng handler -> matches=true (không phân kỳ, '
      'rngSnapshots khớp)',
      () {
        final rng = SeededRandomService(99);
        final recorder = _recordSession(rng, seed: 99, count: 4);

        final signed = ReproductionCapsule.capture(
          recorder: recorder,
          rng: rng,
          appVersion: '1.0.0',
          secret: _secret,
        );

        final result = ReproductionCapsule.replay(
          signed,
          _secret,
          _spinHandler,
        );

        expect(result.divergence, isNull);
        expect(result.rngMismatches, isEmpty);
        expect(result.matches, isTrue);
      },
    );

    test('handler khác (bug logic) -> báo đúng divergence, matches=false', () {
      final rng = SeededRandomService(11);
      final recorder = _recordSession(rng, seed: 11, count: 3);

      final signed = ReproductionCapsule.capture(
        recorder: recorder,
        rng: rng,
        appVersion: '1.0.0',
        secret: _secret,
      );

      final result = ReproductionCapsule.replay(
        signed,
        _secret,
        (event, replayRng) =>
            (replayRng.stream('wheel_spin').nextInt(6) + 1) %
            6, // cố ý lệch +1.
      );

      expect(result.divergence, isNotNull);
      expect(result.matches, isFalse);
    });

    test(
      'rngSnapshots bị drop (size cap nhỏ) -> rngMismatches null, chỉ còn '
      'kiểm tra được divergence',
      () {
        final rng = SeededRandomService(3);
        final recorder = _recordSession(rng, seed: 3, count: 3);

        final signed = ReproductionCapsule.capture(
          recorder: recorder,
          rng: rng,
          appVersion: '1.0.0',
          secret: _secret,
          maxBytes: 200,
        );

        final result = ReproductionCapsule.replay(
          signed,
          _secret,
          _spinHandler,
        );

        expect(result.divergence, isNull);
        expect(result.rngMismatches, isNull);
        expect(result.matches, isTrue);
      },
    );

    test(
      'capsule bị tamper (sửa checksum/dữ liệu) -> throw FormatException, '
      'không silently trust',
      () {
        final rng = SeededRandomService(1);
        final recorder = _recordSession(rng, seed: 1, count: 2);

        final signed = ReproductionCapsule.capture(
          recorder: recorder,
          rng: rng,
          appVersion: '1.0.0',
          secret: _secret,
        );
        final tampered = {...signed, 'appVersion': 'HACKED'};

        expect(
          () => ReproductionCapsule.replay(tampered, _secret, _spinHandler),
          throwsFormatException,
        );
      },
    );
  });
}
