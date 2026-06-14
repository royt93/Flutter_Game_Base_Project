import 'package:get/get.dart';
import '../../core/storage_service.dart';
import '../../data/story.dart';

/// Quản lý overlay cốt truyện (GetX) — hiển thị 1 lần mỗi beat.
class StoryController extends GetxController {
  final RxBool open = false.obs;
  final Rxn<StoryBeat> current = Rxn<StoryBeat>();
  final RxInt line = 0.obs;

  final StorageService _store = StorageService.to;
  void Function()? _onComplete;

  /// Lấy/đăng ký singleton (an toàn khi gọi ở bất kỳ màn nào).
  static StoryController get to => Get.isRegistered<StoryController>()
      ? Get.find<StoryController>()
      : Get.put(StoryController(), permanent: true);

  bool seen(StoryBeat b) =>
      _store.getInt(StorageKeys.storySeen(b.id), def: 0) == 1;

  /// Mở beat nếu CHƯA xem. Trả về true nếu mở (caller nên hoãn hành động kế
  /// tiếp tới khi [onComplete] chạy). Nếu đã xem → false (caller đi tiếp ngay).
  bool maybeShow(StoryTrigger trigger, int world, {void Function()? onComplete}) {
    final b = storyBeatFor(trigger, world);
    if (b == null || seen(b)) return false;
    current.value = b;
    line.value = 0;
    _onComplete = onComplete;
    open.value = true;
    return true;
  }

  void next() {
    final b = current.value;
    if (b == null) return;
    if (line.value < b.lineCount - 1) {
      line.value++;
    } else {
      _finish();
    }
  }

  void prev() {
    if (line.value > 0) line.value--;
  }

  void skip() => _finish();

  void _finish() {
    final b = current.value;
    if (b != null) _store.setInt(StorageKeys.storySeen(b.id), 1);
    open.value = false;
    current.value = null;
    line.value = 0;
    final cb = _onComplete;
    _onComplete = null;
    cb?.call();
  }
}
