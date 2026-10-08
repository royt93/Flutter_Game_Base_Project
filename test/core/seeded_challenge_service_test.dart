import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/core/replay_recorder.dart';
import 'package:roy_casual_kit/core/seeded_challenge_service.dart';
import 'package:roy_casual_kit/core/storage_service.dart';
import 'package:roy_casual_kit/core/utils/clamped_clock.dart';
import 'package:roy_casual_kit/core/utils/seeded_random.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('nonpositive scoreboard capacity is rejected at construction', () {
    for (final capacity in [0, -1]) {
      expect(() => SeededChallengeService(
        challengeId: 'daily', period: ChallengePeriod.daily,
        scoreboardCapacity: capacity,
      ), throwsArgumentError);
    }
  });

  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() {
    setDebugTimeOffsetMs(0);
    Get.reset();
  });

  late StorageService storage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = StorageService(await SharedPreferences.getInstance());
    Get.put(storage, permanent: true);
  });

  group('SeededChallengeService: deterministic seed', () {
    test('cùng challengeId + cùng ngày (periodKey) -> cùng rootSeed, kể cả '
        'instance khác (restart)', () {
      final a = SeededChallengeService(
        challengeId: 'daily_sprint',
        period: ChallengePeriod.daily,
      );
      final b = SeededChallengeService(
        challengeId: 'daily_sprint',
        period: ChallengePeriod.daily,
      );

      expect(a.currentSeed, b.currentSeed);
    });

    test('challengeId khác nhau -> rootSeed khác nhau cùng ngày', () {
      final a = SeededChallengeService(
        challengeId: 'daily_sprint',
        period: ChallengePeriod.daily,
      );
      final b = SeededChallengeService(
        challengeId: 'daily_boss',
        period: ChallengePeriod.daily,
      );

      expect(a.currentSeed, isNot(b.currentSeed));
    });

    test(
      'daily và weekly cùng challengeId -> periodKey khác nên seed khác',
      () {
        final daily = SeededChallengeService(
          challengeId: 'sprint',
          period: ChallengePeriod.daily,
        );
        final weekly = SeededChallengeService(
          challengeId: 'sprint',
          period: ChallengePeriod.weekly,
        );

        expect(daily.currentSeed, isNot(weekly.currentSeed));
      },
    );

    test('qua ngày mới -> seed đổi (periodKey đổi)', () {
      final service = SeededChallengeService(
        challengeId: 'daily_sprint',
        period: ChallengePeriod.daily,
      );
      final seedDay1 = service.currentSeed;

      setDebugTimeOffsetMs(const Duration(days: 2).inMilliseconds);
      final seedDay2 = service.currentSeed;

      expect(seedDay1, isNot(seedDay2));
    });
  });

  group('SeededChallengeService: RNG stream snapshot/resume', () {
    test(
      'startRun() cấp SeededRandomService cùng rootSeed; snapshot/resume tạo '
      'chuỗi tiếp theo giống hệt chạy liên tục không ngắt',
      () {
        final service = SeededChallengeService(
          challengeId: 'daily_sprint',
          period: ChallengePeriod.daily,
        );

        final continuous = service.startRun();
        final values1 = List.generate(
          5,
          (_) => continuous.stream('gameplay').nextInt(1000),
        );

        final fresh = service.startRun();
        final rng = fresh.stream('gameplay');
        final firstHalf = List.generate(2, (_) => rng.nextInt(1000));
        final snapshot = rng.snapshot();
        final resumed = SeededRandom.fromSnapshot(snapshot);
        final secondHalf = List.generate(3, (_) => resumed.nextInt(1000));

        expect([...firstHalf, ...secondHalf], values1);
      },
    );
  });

  group('SeededChallengeService: replay determinism + divergence', () {
    test(
      'replay cùng seed/input -> score deterministic, không báo divergence',
      () {
        final service = SeededChallengeService(
          challengeId: 'daily_sprint',
          period: ChallengePeriod.daily,
        );
        final recorder = ReplayRecorder();
        final rng = service.startRun(recorder: recorder);

        for (var i = 0; i < 5; i++) {
          final roll = rng.stream('gameplay').nextInt(100);
          recorder.record('roll', {'expectedOutcome': roll});
        }
        final capsule = service.endRun(recorder);

        final result = service.replay(capsule, (event, replayRng) {
          return replayRng.stream('gameplay').nextInt(100);
        });

        expect(result.matches, isTrue);
      },
    );

    test('replay input khác -> báo divergence, không silent pass', () {
      final service = SeededChallengeService(
        challengeId: 'daily_sprint',
        period: ChallengePeriod.daily,
      );
      final recorder = ReplayRecorder();
      final rng = service.startRun(recorder: recorder);
      for (var i = 0; i < 3; i++) {
        final roll = rng.stream('gameplay').nextInt(100);
        recorder.record('roll', {'expectedOutcome': roll});
      }
      final capsule = service.endRun(recorder);

      final result = service.replay(capsule, (event, replayRng) {
        // Tampered handler: always returns a wrong/fixed value, simulating
        // a cheater's modified client producing different outcomes from
        // the SAME recorded seed/events.
        return -1;
      });

      expect(result.matches, isFalse);
      expect(result.divergence, isNotNull);
    });
  });

  group('SeededChallengeService: local scoreboard, no network', () {
    test('submitScore ghi vào LocalScoreboardService scoped theo challengeId + '
        'periodKey — 2 challenge khác nhau không đụng bảng của nhau', () {
      final sprint = SeededChallengeService(
        challengeId: 'daily_sprint',
        period: ChallengePeriod.daily,
      );
      final boss = SeededChallengeService(
        challengeId: 'daily_boss',
        period: ChallengePeriod.daily,
      );

      sprint.submitScore('player1', 500);
      boss.submitScore('player1', 999);

      expect(sprint.topScores(5).single.score, '500');
      expect(boss.topScores(5).single.score, '999');
    });

    test(
      'qua kỳ mới (ngày khác) -> bảng xếp hạng mới trống, không kế thừa',
      () {
        final service = SeededChallengeService(
          challengeId: 'daily_sprint',
          period: ChallengePeriod.daily,
        );
        service.submitScore('player1', 500);
        expect(service.topScores(5), hasLength(1));

        setDebugTimeOffsetMs(const Duration(days: 1).inMilliseconds);

        expect(service.topScores(5), isEmpty);
      },
    );
  });

  group('SeededChallengeService: clock rewind cannot reopen an old period', () {
    test('lùi đồng hồ sau khi đã sang kỳ mới -> vẫn ở kỳ mới (periodKey không '
        'lùi lại)', () {
      final service = SeededChallengeService(
        challengeId: 'daily_sprint',
        period: ChallengePeriod.daily,
      );
      final seedDay1 = service.currentSeed;

      setDebugTimeOffsetMs(const Duration(days: 3).inMilliseconds);
      final seedDay4 = service.currentSeed;
      expect(seedDay4, isNot(seedDay1));

      setDebugTimeOffsetMs(0);
      final seedAfterRewind = service.currentSeed;

      expect(seedAfterRewind, seedDay4);
    });
  });

  group('SeededChallengeService: constructor validation', () {
    test('challengeId rỗng -> ArgumentError', () {
      expect(
        () => SeededChallengeService(
          challengeId: '',
          period: ChallengePeriod.daily,
        ),
        throwsArgumentError,
      );
    });
  });
}
