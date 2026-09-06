/// Platform-neutral cloud save/account-linking seam. Without this,
/// `StorageService` is 100% local `SharedPreferences` — a lost/reinstalled
/// device loses all progress. The package pulls in no cloud SDK; a
/// consuming app implements this against Google Play Games Services /
/// Game Center / Firebase Auth+Firestore and passes it to
/// [VersionedJsonStore.syncWith].
abstract class CloudSaveProvider {
  Future<void> signIn();
  Future<void> upload(Map<String, Object?> data);
  Future<Map<String, Object?>?> download();
}
