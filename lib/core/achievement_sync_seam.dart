import 'package:get/get.dart';

import 'achievement_service.dart';
import 'utils/sdk_result.dart';

/// Platform-neutral achievement-sync seam — the package ships no Play Games /
/// Game Center client. The consuming app registers its own adapter via
/// `Get.put<AchievementSyncSeam>(myAdapter, permanent: true)`, same pattern
/// as [LeaderboardSyncSeam]-style seams. Progress is a plain
/// `achievementId -> progress` map; thresholds stay in the app.
abstract class AchievementSyncSeam {
  /// Atomically merges each uploaded value with the backend value using max.
  Future<void> pushProgress(Map<String, int> progress);

  /// Downloads the backend's progress map, or `null` when it has none yet.
  Future<Map<String, int>?> pullProgress();

  static AchievementSyncSeam? get maybe =>
      Get.isRegistered<AchievementSyncSeam>()
      ? Get.find<AchievementSyncSeam>()
      : null;
}

/// Pulls remote progress, merges it into [service] with `max(local, remote)`
/// per achievement, then pushes the merged map back. Progress only grows, so
/// two devices converge without losing either side's data. Resetting or
/// lowering progress is not supported by this merge.
class AchievementSyncCoordinator {
  AchievementSyncCoordinator({required this.service, AchievementSyncSeam? seam})
    : _seam = seam;

  final AchievementService service;
  final AchievementSyncSeam? _seam;

  /// Returns how many local achievements the remote copy raised. No seam
  /// registered means nothing to sync: `SdkSuccess(0)`. A failed pull leaves
  /// local progress untouched; a failed push keeps the merged local progress
  /// (already saved) and reports the failure so the caller can retry.
  Future<SdkResult<int>> sync() async {
    final seam = _seam ?? AchievementSyncSeam.maybe;
    if (seam == null) return const SdkSuccess(0);

    final Map<String, int>? remote;
    try {
      remote = await seam.pullProgress();
    } catch (error, stack) {
      return SdkFailure(
        kind: SdkErrorKind.network,
        message: 'Failed to pull achievement progress',
        retryable: true,
        cause: error,
        stackTrace: stack,
      );
    }

    final merged = await service.mergeProgressDurably(remote ?? const {});
    if (merged case SdkFailure<int>()) return merged;
    final raised = (merged as SdkSuccess<int>).value;

    try {
      await seam.pushProgress(service.progressSnapshot);
    } catch (error, stack) {
      return SdkFailure(
        kind: SdkErrorKind.network,
        message: 'Failed to push achievement progress',
        retryable: true,
        cause: error,
        stackTrace: stack,
      );
    }
    return SdkSuccess(raised);
  }
}
