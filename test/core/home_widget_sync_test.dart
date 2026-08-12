import 'package:flutter_test/flutter_test.dart';
import 'package:pop_star_blast/core/home_widget_sync.dart';

/// `syncHomeWidget` (I74) — 24 dòng, không có test riêng trước [[T5]].
///
/// Chỉ có đúng một hợp đồng đáng chốt: **nuốt mọi lỗi**. Nó chạy trên platform
/// channel `home_widget`, thứ không tồn tại trong test và có thể vắng trên
/// launcher thật. Nếu nó ném, lời gọi từ `GameController._scheduleWidgetSync()`
/// sẽ làm hỏng chính luồng cộng thưởng — đánh đổi tệ cho một tính năng trang trí.
///
/// Hợp đồng này lâu nay chỉ được chứng minh *tình cờ*: cả bộ test xanh trong
/// khi log đầy `MissingPluginException`. Ca dưới ghim nó lại rõ ràng.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('thiếu platform channel -> không ném, không treo', () async {
    await expectLater(syncHomeWidget(streak: 3, coins: 120), completes);
  });

  test('giá trị biên (0 và âm) cũng không ném', () async {
    await expectLater(syncHomeWidget(streak: 0, coins: 0), completes);
    await expectLater(syncHomeWidget(streak: -1, coins: -1), completes);
  });
}
