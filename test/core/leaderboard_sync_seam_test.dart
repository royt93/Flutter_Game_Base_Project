import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/core/leaderboard_sync_seam.dart';
import 'package:roy_casual_kit/core/local_scoreboard_service.dart';
import 'package:roy_casual_kit/core/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeLeaderboardSyncSeam implements LeaderboardSyncSeam {
  final Map<String, List<ScoreEntry>> boards = {};
  bool failNextCall = false;
  int submitCalls = 0;

  @override
  Future<void> submitScore(String boardId, int score) async {
    submitCalls++;
    if (failNextCall) {
      failNextCall = false;
      throw Exception('backend unreachable');
    }
    (boards[boardId] ??= []).add(ScoreEntry(playerLabel: 'remote', score: score));
  }

  @override
  Future<List<ScoreEntry>> fetchTop(String boardId, {int limit = 10}) async {
    if (failNextCall) {
      failNextCall = false;
      throw Exception('backend unreachable');
    }
    return boards[boardId]?.take(limit).toList() ?? const [];
  }

  @override
  Future<List<ScoreEntry>> fetchAroundPlayer(
    String boardId, {
    int radius = 2,
  }) async {
    if (failNextCall) {
      failNextCall = false;
      throw Exception('backend unreachable');
    }
    return boards[boardId] ?? const [];
  }
}

void main() {
  tearDown(Get.reset);

  late StorageService storage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = StorageService(await SharedPreferences.getInstance());
    Get.put(storage, permanent: true);
  });

  group('LeaderboardSyncSeam.maybe', () {
    test('trả về null khi chưa đăng ký implementation nào', () {
      expect(LeaderboardSyncSeam.maybe, isNull);
    });

    test('trả về đúng instance khi đã đăng ký', () {
      final seam = _FakeLeaderboardSyncSeam();
      Get.put<LeaderboardSyncSeam>(seam, permanent: true);

      expect(LeaderboardSyncSeam.maybe, same(seam));
    });
  });

  group('LeaderboardSyncCoordinator: LocalScoreboardService vẫn hoạt động độc lập', () {
    test('submitScore/topN hoạt động bình thường khi không có seam nào đăng ký', () {
      final local = LocalScoreboardService();
      local.submitScore('Roy', 100);

      expect(local.topN(10), hasLength(1));
      expect(LeaderboardSyncSeam.maybe, isNull);
    });
  });

  group('LeaderboardSyncCoordinator: submitScore', () {
    test('luôn ghi vào local ngay lập tức, kể cả khi không có seam', () async {
      final local = LocalScoreboardService();
      final coordinator = LeaderboardSyncCoordinator(local: local);

      await coordinator.submitScore('weekly', 'Roy', 100);

      expect(local.topN(10), hasLength(1));
      expect(local.topN(10).first.score, contains('100'));
    });

    test('forward best-effort lên seam khi có seam đăng ký', () async {
      final local = LocalScoreboardService();
      final seam = _FakeLeaderboardSyncSeam();
      final coordinator = LeaderboardSyncCoordinator(local: local, seam: seam);

      await coordinator.submitScore('weekly', 'Roy', 100);

      expect(seam.submitCalls, 1);
      expect(local.topN(10), hasLength(1));
    });

    test(
      'seam.submitScore lỗi (mất mạng) không làm mất bản ghi local đã lưu',
      () async {
        final local = LocalScoreboardService();
        final seam = _FakeLeaderboardSyncSeam()..failNextCall = true;
        final coordinator = LeaderboardSyncCoordinator(
          local: local,
          seam: seam,
        );

        await expectLater(
          coordinator.submitScore('weekly', 'Roy', 100),
          completes,
        );

        expect(local.topN(10), hasLength(1));
      },
    );
  });

  group('LeaderboardSyncCoordinator: fetchTop', () {
    test('đọc từ seam khi seam có đăng ký và thành công', () async {
      final local = LocalScoreboardService();
      final seam = _FakeLeaderboardSyncSeam();
      seam.boards['weekly'] = [
        const ScoreEntry(playerLabel: 'RemotePlayer', score: 999),
      ];
      final coordinator = LeaderboardSyncCoordinator(local: local, seam: seam);

      final result = await coordinator.fetchTop('weekly', limit: 5);

      expect(result, hasLength(1));
      expect(result.first.playerLabel, 'RemotePlayer');
      expect(result.first.score, 999);
    });

    test(
      'fallback về local khi seam throw (mất mạng), không trả về rỗng',
      () async {
        final local = LocalScoreboardService();
        local.submitScore('Roy', 50);
        final seam = _FakeLeaderboardSyncSeam()..failNextCall = true;
        final coordinator = LeaderboardSyncCoordinator(
          local: local,
          seam: seam,
        );

        final result = await coordinator.fetchTop('weekly', limit: 5);

        expect(result, hasLength(1));
        expect(result.first.playerLabel, 'Roy');
        expect(result.first.score, 50);
      },
    );

    test('fallback về local khi không có seam nào đăng ký', () async {
      final local = LocalScoreboardService();
      local.submitScore('Roy', 50);
      final coordinator = LeaderboardSyncCoordinator(local: local);

      final result = await coordinator.fetchTop('weekly', limit: 5);

      expect(result, hasLength(1));
      expect(result.first.score, 50);
    });
  });

  group('LeaderboardSyncCoordinator: fetchAroundPlayer', () {
    test('fallback về local.entriesAround khi seam throw', () async {
      final local = LocalScoreboardService();
      local.submitScore('A', 300);
      local.submitScore('B', 200);
      local.submitScore('C', 100);
      final seam = _FakeLeaderboardSyncSeam()..failNextCall = true;
      final coordinator = LeaderboardSyncCoordinator(local: local, seam: seam);

      final result = await coordinator.fetchAroundPlayer(
        'weekly',
        'B',
        radius: 1,
      );

      expect(result.map((e) => e.playerLabel), ['A', 'B', 'C']);
    });
  });
}
