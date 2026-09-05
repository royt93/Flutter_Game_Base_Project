# Review roy_casual_kit — nhận xét của Claude

Phạm vi đọc: toàn bộ `lib/core/`, `lib/core/utils/`, `lib/presentation/widgets/` (neon kit + `common/`, 22 widget), `example/lib/` (main.dart + 3 screen), cùng các test tương ứng ở `test/` và `example/test/` + `example/integration_test/`.

---

## 1) Bug / vấn đề CẦN FIX

### Mức cao

1. **`example/lib/main.dart:41-54` — `Get.put(..., permanent: true)` không guard `Get.isRegistered`, gọi lại `app()` trong cùng process sẽ dùng instance CŨ mà không cảnh báo.**
   Đã verify trong mã nguồn `get_instance.dart` của package `get`: khi key đã đăng ký và `isDirty == false` (đúng trạng thái một permanent singleton), `Get.put()` lần sau bị bỏ qua âm thầm, `find<S>()` vẫn trả instance cũ. Code tự thừa nhận kịch bản này ở comment dòng 46-50 (test gọi lại `app()`) nhưng chỉ vá thủ công `Get.updateLocale()`, còn `StorageService`/`ReminderService`/`AudioManager` cũ vẫn được tái sử dụng với state có thể stale. Rủi ro thật khi có thêm integration test hoặc hot-restart gọi `app()` nhiều lần mà quên `Get.reset()`.

2. **`lib/presentation/widgets/common/icon_badge_button.dart:49` — thiếu tham số `semanticLabel`, mặc định dùng `icon.toString()` làm label cho Semantics.**
   Screen reader sẽ đọc ra chuỗi kiểu `IconData(U+0E88F)`, vô nghĩa với người dùng khiếm thị. `CommonButton` (cùng bộ) đã có tham số này ở dòng 41 — bất nhất ngay trong cùng file barrel.

3. **`lib/presentation/widgets/common/list_tile_row.dart` (`CommonListTile`) — widget có `onTap` nhưng không bọc `Semantics(button: true, ...)`.**
   Mọi widget tappable khác trong bộ (`CommonButton`, `IconBadgeButton`, `SegmentedTabBar`, `ToggleSwitch`) đều làm việc này. Thiếu sót accessibility rõ ràng và không nhất quán trong cùng bộ widget.

4. **`lib/presentation/widgets/common/toast_banner.dart:77-105` — `Future.delayed(duration, remove)` không try/catch, `AnimationController` dùng `vsync: Navigator.of(context)`.**
   Nếu route bị pop trước khi callback chạy, `controller.reverse()/dispose()` gọi trên ticker đã dispose → exception không xử lý, rơi ra ngoài build.

5. **`test/core/storage_service_test.dart` (thiếu, không phải bug code nhưng nghiêm trọng) — không có test nào cho `setIntBuffered`/`setStringBuffered`/`flush()`/`platformWrites`.**
   Đây chính là cơ chế phức tạp và dễ vỡ nhất của `StorageService` (write-behind buffer, đã được doc kỹ ở đầu file về "cái bẫy chính") nhưng hoàn toàn không có bằng chứng test xác nhận đúng hành vi.

### Mức trung bình

6. **`lib/core/audio_manager.dart:76-91` — nhánh dọn dẹp `AudioPlayer` là dead code.**
   `_ignoreAudio` được gọi với kết quả của `FlameAudio.bgm.play/pause/resume/stop`, cả 4 hàm này trong `flame_audio` đều trả `Future<void>`, không bao giờ trả `AudioPlayer`. Điều kiện `value is AudioPlayer` (dòng ~78) luôn `false` → toàn bộ logic `timeout(5s)/dispose` không bao giờ chạy. Không crash, nhưng ý định "tự dọn player sau khi phát" hoàn toàn vô hiệu, dễ đánh lừa người đọc code sau này.

7. **`lib/core/share_helper.dart:29` — `ctx.findRenderObject() as RenderRepaintBoundary` không try/catch.**
   Gọi sai chỗ (key không gắn vào `RepaintBoundary`, hoặc gọi khi `debugNeedsPaint == true`) sẽ ném exception không bắt, crash tại call site (`shareBoardImage`/`shareScoreCard` không có try/catch bao ngoài).

8. **`lib/core/share_helper.dart:57` — `maxWidth: w - 24 * pixelRatio` có thể ra âm với board rất nhỏ**, gây assert lỗi trong `TextPainter.layout` ở debug. Không có clamp ở boundary.

9. **`lib/presentation/widgets/common/progress_bar_stars.dart:77` — `(w * t - 12).clamp(0.0, w - 24)` ném `ArgumentError` nếu `constraints.maxWidth < 24`.**
   `tooltip_bubble.dart` xử lý case tương tự đúng cách (fallback khi `minCenter <= maxCenter`) nhưng file này thì không — thiếu guard nhất quán trong cùng bộ.

10. **`lib/presentation/widgets/common/common_button.dart:101-102,110` — `label!` không có runtime guard ngoài `assert` (chỉ chạy debug).**
    Nếu variant `primary/secondary/danger` lỡ gọi với `label = null` ở release/profile build, crash "Null check operator used on a null value" ngay lập tức, không có thông báo lỗi rõ ràng.

11. **`lib/core/reminder_service.dart:37-53` — lỗi lịch thông báo bị nuốt hoàn toàn**, chỉ `dlog()` (no-op ở release). Không có cách nào cho caller biết `scheduleNext` thất bại để retry hoặc báo cho người dùng — tính năng "nhắc chơi lại" có thể âm thầm không hoạt động trên một số thiết bị (permission bị từ chối, plugin lỗi...).

### Mức thấp

12. `star_rating.dart` không override `didUpdateWidget`: đổi `animate` từ `false` → `true` sau khi widget đã tồn tại thì animation không bao giờ chạy (controller chỉ tạo trong `initState`).
13. Thiếu `key` ổn định cho các list sinh động bằng `List.generate`/`for` trong `segmented_tab_bar.dart:62`, `star_rating.dart:52`, `progress_bar_stars.dart:75` — vô hại với số lượng cố định hiện tại, nhưng rủi ro nếu số phần tử đổi động giữa các build.
14. `lib/core/runtime_flags.dart:5` (`isE2eTest`) là cờ chết — `grep` toàn repo chỉ ra đúng 1 chỗ định nghĩa, không nơi nào dùng. `CLAUDE.md` mô tả nó dùng để skip audio init khi test tự động, nhưng `example/lib/main.dart` không hề tham chiếu tới nó; `app_boot_test.dart` gọi cứng `withAudio: false` thay vì dựa vào flag. Tài liệu và code đang lệch nhau.
15. `example/lib/screens/widget_showcase_screen.dart:87-106` dùng `showDialog` gốc của Flutter thay vì `NeonDialog`, trong khi chính CLAUDE.md khuyến nghị luôn ưu tiên overlay pattern và file này được ghi chú là "living reference" cho cách dùng widget kit — mẫu tham khảo tự vi phạm khuyến nghị của chính nó.

---

## 2) Tính năng đã có nhưng CẦN ENHANCE

1. **`StorageService` buffered API bất đối xứng**: chỉ có `setIntBuffered`/`setStringBuffered`, trong khi `flush()` đã xử lý cả 4 kiểu dữ liệu (int/string/bool/double). Nên bổ sung `setBoolBuffered`/`setDoubleBuffered` cho nhất quán — counter dạng bool (ví dụ "đã xem intro chưa") cũng là hot-path đáng buffer.
2. **`SegmentedTabBar`** hardcode `NeonTheme.cyan` cho pill active (`segmented_tab_bar.dart:50`), không có tham số `color`/`accentColor` để tùy biến — trong khi hầu hết widget cùng bộ (`CommonButton`, `IconBadgeButton`, `CircularProgressRing`, `ProgressBarStars`) đều expose màu sắc.
3. **`CommonButton.width`** bị overload nghĩa (vừa là "pill width" vừa là "diameter" cho variant icon, tự thừa nhận trong comment) — nên tách 2 tham số riêng cho rõ API.
4. Text không giới hạn dòng ở nhiều widget hàng đơn (`list_tile_row.dart`, `section_header.dart`, `toast_banner.dart`) — thiếu `maxLines`/`overflow: ellipsis`, chuỗi dài (đặc biệt bản dịch tiếng Đức/Nga...) sẽ phá layout dự kiến 1 dòng.
5. **`NeonTheme.dark`** là `static bool` mutable toàn cục, không reactive — đổi giá trị không tự trigger rebuild UI (phải tự `setState`/`Get.forceAppUpdate()` ở nơi gọi), và không được reset giữa các test file nên có nguy cơ leak trạng thái khi chạy song song. Nên cân nhắc bọc bằng `Rx<bool>` hoặc ít nhất document rõ nghĩa vụ gọi `forceAppUpdate` sau khi đổi.
6. **`ReminderService` kế thừa `GetxController`** trong khi 3 service còn lại (`StorageService`, `LocaleService`, `AudioManager`) đều là `GetxService` — thiếu nhất quán lifecycle base class trong cùng kit lõi.
7. Test coverage cực mỏng cho widget kit: chỉ 1/21 widget trong `common/` có test (`reward_popup_smoke_test.dart`). Các widget rủi ro cao nhất về logic (`ToastBanner.show`, `ProgressBarStars`, `CommonButton` assert, animation lifecycle của `CurrencyCounter`/`StarRating`) chưa hề được test.
8. Toàn bộ kit dùng toạ độ vật lý (`left`/`right`, `Alignment`) thay vì `AlignmentDirectional`/`PositionedDirectional` — sẽ hiển thị sai khi bật RTL (Ả Rập, Hebrew) nếu kit được dùng cho app đa ngôn ngữ toàn cầu.
9. `NeonDialog` có 3 API (`show`/`overlay`/`overlaySlot`) nhưng không có cách nào tự động cảnh báo nếu dùng nhầm API trong ngữ cảnh có `GameWidget` — chỉ dựa vào người đọc comment. Một `assert` debug-only phát hiện `GameWidget` ancestor khi gọi `show()` sẽ an toàn hơn.

---

## 3) Tính năng MỚI nên thêm cho 1 base game kit

Đây là những mảng mà hầu hết casual/idle game khi build từ đầu đều cần, và kit hiện tại (storage/i18n/audio/haptics/reminder/theme/widget) đã có nền tốt nhưng còn thiếu các mảnh ghép sau:

1. **Economy/Currency service** — soft-currency, hard-currency, cơ chế earn/spend có transaction log tối thiểu (chống double-spend do double-tap), tích hợp sẵn với `StorageService` (dùng `setInt` không buffer cho transaction thật, đúng tinh thần "purchase/reset never buffered" đã ghi trong CLAUDE.md). `CurrencyCounter` widget đã có UI, nhưng chưa có service quản lý số dư đứng sau nó.
2. **Analytics/event-tracking abstraction** — một interface trung lập (không ép buộc Firebase/Amplitude cụ thể) để log event kiểu `logEvent(name, params)`, cho phép game dán adapter riêng. Mọi casual game production đều cần funnel/retention tracking ngày 1.
3. **Remote Config / feature-flag layer nhẹ** — kit đã có `StorageService` local, nhưng chưa có cơ chế đọc config từ xa (A/B test độ khó, bật/tắt sự kiện) với fallback về default cứng khi offline.
4. **Daily reward / streak calendar service** — `StreakCounter` widget đã có UI, `ClampedClock` đã chống gian lận đồng hồ, nhưng chưa có service hoàn chỉnh nối 2 thứ này lại thành "daily login reward" có lịch 7 ngày, claim state, và reset logic khi bỏ lỡ 1 ngày.
5. **In-app review / rating prompt helper** — wrapper mỏng quanh `in_app_review`, với logic "chỉ hỏi sau N lần thắng và chưa từng bị từ chối" — pattern gần như bắt buộc ở mọi casual game, hiện phải tự viết lại mỗi lần.
6. **Save-game slot / progress serialization helper** — hiện `StorageService` chỉ có key-value đơn giản; game có level/map cần một lớp mỏng serialize/deserialize JSON có versioning (migrate khi đổi schema level cũ → mới) mà không phải tự lo từ đầu.
7. **Onboarding/tutorial overlay primitive** — một `SpotlightOverlay`/`CoachMark` (highlight 1 vùng, dim phần còn lại, mũi tên trỏ) generic dùng chung `NeonDialog.overlay` pattern đã có sẵn — rất thường gặp trong casual game nhưng chưa có trong bộ 21 widget hiện tại.
8. **Ads mediation adapter interface** (không cần implement, chỉ cần abstraction) — interface `RewardedAdProvider`/`InterstitialAdProvider` trung lập để game cắm AdMob/IronSource/Applovin vào mà không phải tự thiết kế lifecycle (load/show/onReward/onFail) từ đầu — khớp tự nhiên với patttern `AudioManager.maybe` (null-safe accessor) đã dùng trong kit.
9. **Crash-safe migration cho `StorageKeys`** — hiện mỗi key là 1 const string cố định; nên có helper đổi tên key an toàn (đọc key cũ, ghi key mới, xoá key cũ) để version sau của game không mất dữ liệu người chơi khi refactor tên field.

---

## 4) Idea độc quyền — giúp kit này nổi bật trên thị trường

Phần lớn "casual game kit" trên pub.dev (flame, flutter_game_engine templates...) tập trung vào render/physics. Điểm khác biệt của `roy_casual_kit` hiện tại là **hạ tầng service tối giản, chống-gian-lận, và widget kit candy-style đóng gói sẵn** — đây là hướng nên đào sâu hơn thay vì cạnh tranh về engine:

1. **"Anti-cheat clock" mở rộng thành full offline-progress engine.** `ClampedClock` đã giải quyết vấn đề lùi giờ để cheat — không nhiều kit làm điều này. Có thể biến nó thành điểm bán độc quyền: 1 module "Offline Earnings" tính toán reward tích luỹ khi người chơi quay lại sau X phút vắng mặt, dùng chính `ClampedClock` làm nguồn thời gian tin cậy duy nhất — vốn là bài toán đau đầu nhất của thể loại idle game và hiếm kit nào có sẵn cơ chế chống gian lận đúng đắn cho nó.
2. **Adaptive haptic "feel" profile theo combo/streak** — `fireHaptic(HapticLevel)` hiện là API tĩnh theo mức độ; có thể mở rộng thành 1 "haptic choreography" tự động tăng cường độ theo streak hiện tại (giống Balatro/Vampire Survivors dùng feedback rung/âm thanh leo thang) — đóng gói sẵn cấu hình cho non-designer dev, khác biệt so với các kit chỉ expose raw `HapticFeedback`.
3. **"1 file = 1 theme" marketplace-ready token pack.** `NeonTheme` đã tách token khỏi widget rất sạch (đổi `dark` không cần sửa call site). Có thể đóng gói thành N bộ theme sẵn (candy/neon/pastel/retro-arcade) dưới dạng file token độc lập, để dev chỉ cần import 1 file để "reskin" toàn bộ 21 widget common trong vài phút — biến kit thành nền tảng "reskin nhanh" cho các studio làm nhiều game cùng lúc (rất đúng nhu cầu hyper-casual studio, nơi reskin tốc độ là lợi thế cạnh tranh chính).
4. **Overlay-first dialog pattern đã có sẵn cho Flame `GameWidget`** — đây thực sự là điểm khác biệt kỹ thuật hiếm thấy: hầu hết kit UI Flutter không tính đến việc `Navigator`/`Get.dialog` bị vô hiệu hoá bởi 1 `GameWidget` full-screen. `NeonDialog.overlay` đã giải quyết đúng vấn đề này — nên quảng bá rõ ràng đây là lý do chọn kit này thay vì tự chế dialog khi build game có Flame, và bổ sung thêm asset ("overlay-safe" bottom sheet, toast, tooltip — vốn `BottomSheetPanel`/`ToastBanner`/`TooltipBubble` hiện tại vẫn cần rà lại xem có tương thích overlay pattern hay không).
5. **Bộ "casual game health-check" dev tool tích hợp sẵn** — 1 debug overlay (chỉ build trong debug/profile, dùng `dlog` pattern đã có) hiển thị real-time: số write buffered chưa flush, trạng thái audio mute, haptic level hiện tại, offline-time đã clamp bao nhiêu lần — giúp dev tự tin rằng các cơ chế chống-gian-lận/tối-ưu-ghi-đĩa đang hoạt động đúng mà không cần cắm thêm DevTools ngoài.

---

*Ghi chú phương pháp: các finding ở mục 1 được tổng hợp từ việc đọc trực tiếp toàn bộ source `lib/` và `example/lib/` cùng test liên quan; mục 3-4 là đề xuất định hướng dựa trên khoảng trống quan sát được so với nhu cầu thực tế của casual/idle game, cần thảo luận thêm với chủ dự án trước khi triển khai.*
