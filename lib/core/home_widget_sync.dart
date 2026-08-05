import 'package:home_widget/home_widget.dart';

import 'debug_log.dart';
import 'storage_service.dart';

/// I74: đồng bộ dữ liệu hiển thị trên Home Screen Widget (streak + coin).
/// Gọi tập trung qua `GameController._scheduleWidgetSync()` (coalesce nhiều
/// thay đổi coins/loginStreakCount trong cùng 1 tick bằng `scheduleMicrotask`,
/// không dùng `Timer` — tránh leak khi test teardown qua `Get.reset()` bỏ
/// qua `onClose()`) — không gọi tay rải rác ở từng chỗ cộng thưởng.
Future<void> syncHomeWidget({required int streak, required int coins}) async {
  try {
    await Future.wait([
      HomeWidget.saveWidgetData<int>(StorageKeys.widgetStreakKey, streak),
      HomeWidget.saveWidgetData<int>(StorageKeys.widgetCoinsKey, coins),
    ]);
    await HomeWidget.updateWidget(androidName: 'StreakWidgetProvider');
  } catch (e) {
    // Best-effort: không có platform channel (vd chạy trong test) hoặc
    // launcher không hỗ trợ widget — không ảnh hưởng gameplay, nhưng vẫn
    // log để không che mất lỗi tích hợp thật (vd sai androidName).
    dlog('syncHomeWidget lỗi: $e');
  }
}
