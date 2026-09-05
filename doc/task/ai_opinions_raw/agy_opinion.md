# ĐÁNH GIÁ VÀ ĐỀ XUẤT NÂNG CẤP PACKAGE `roy_casual_kit`
> **Người thực hiện:** AI Reviewer (Antigravity)  
> **Dự án:** `roy_casual_kit` (Flutter Casual/Idle Game Base Kit dùng GetX + Flame)  
> **Phạm vi kiểm tra:** Toàn bộ mã nguồn trong `lib/` và `example/lib/`

---

## 1. DANH SÁCH BUG / TASK CẦN FIX (Kèm File:Line Cụ Thể)

Dưới đây là các lỗi thực tế, rủi ro sập ứng dụng, rò rỉ bộ nhớ và vi phạm tiêu chuẩn package được phát hiện trong mã nguồn:

### 1.1. [Treo Future vĩnh viễn / Rò rỉ bộ nhớ] `Completer<bool>` không bao giờ hoàn thành khi đóng dialog qua Back phím cứng
- **Vị trí:** `lib/presentation/widgets/common/confirm_dialog.dart:26-47`
- **Mô tả lỗi:** Hàm `showConfirmDialog` khởi tạo `final completer = Completer<bool>()` và chỉ gọi `completer.complete(...)` khi người dùng bấm vào một trong hai nút của `actions`. Mặc dù `dismissible` là `false` để ngăn bấm vào barrier, nhưng trên thiết bị Android, người dùng vẫn có thể bấm **nút Back vật lý** hoặc **vuốt cử chỉ Back hệ thống** (hoặc phím `Escape` trên Desktop/Web) để đóng dialog. Khi đó `NeonDialog.show` kết thúc nhưng không có nút nào được bấm, dẫn đến `completer` không bao giờ complete. Bất kỳ lệnh `await showConfirmDialog(...)` nào trong code gọi sẽ bị **treo vĩnh viễn** (freeze logic màn hình).
- **Cách khắc phục:** Lắng nghe khi `NeonDialog.show` pop bằng cách dùng `.then(...)` để kiểm tra:  
  ```dart
  NeonDialog.show<void>(...).then((_) {
    if (!completer.isCompleted) completer.complete(false);
  });
  ```

---

### 1.2. [Lỗi Trợ năng / Missing Translation Key] Thiếu key `'back_button_label'` trong `AppTranslations`
- **Vị trí:** `lib/presentation/widgets/neon_icon.dart:47` và `lib/core/app_translations.dart:16-35`
- **Mô tả lỗi:** Trong `NeonBackButton`, `semanticLabel` được gán bằng `'back_button_label'.tr`. Tuy nhiên, trong file `AppTranslations`, danh sách dịch của cả 2 ngôn ngữ (`en`, `vi`) chỉ chứa các keys: `app_name`, `settings`, `language`, `sound`, `ok`, `cancel`, `widget_showcase`. Hoàn toàn không có key `'back_button_label'`. Khi người dùng bật trình đọc màn hình trợ năng (TalkBack/VoiceOver), máy sẽ đọc thô chuỗi `'back_button_label'` thay vì đọc nhãn nút quay lại.
- **Cách khắc phục:** Bổ sung key `'back_button_label'` vào cả hai map `'en'` (`'Back'`) và `'vi'` (`'Quay lại'`) trong `AppTranslations`.

---

### 1.3. [Lỗi Logic Hiển thị Thời gian] `fmtDur` bị cắt/sai khi thời lượng đếm ngược vượt quá 60 phút
- **Vị trí:** `lib/core/utils/format.dart:8-12`
- **Mô tả lỗi:** Hàm `fmtDur(Duration d)` tính phút bằng công thức `d.inMinutes.remainder(60)`. Trong game casual/idle, các bộ đếm thời gian (như thời gian hồi đầy thanh năng lượng, thời gian mở rương kho báu, sự kiện boss) thường kéo dài từ 2 đến 24 giờ. Nếu thời lượng là 75 phút, `remainder(60)` sẽ trả về `15`, khiến chuỗi hiển thị thành `"15:00"` (người chơi tưởng chỉ còn 15 phút) thay vì `"75:00"` hoặc `"01:15:00"`.
- **Cách khắc phục:** Nếu `d.inHours > 0`, định dạng thành `hh:mm:ss`; nếu `< 1 giờ`, giữ `mm:ss` với `d.inMinutes` không lấy modulo 60.

---

### 1.4. [Rò rỉ Bộ nhớ GPU / Native VRAM Leak] Quên `dispose()` đối tượng `FragmentShader`
- **Vị trí:** 
  - `lib/presentation/widgets/aurora_bg_layer.dart:65-68`
  - `lib/presentation/widgets/neon_aura_layer.dart:64-67`
- **Mô tả lỗi:** `ui.FragmentShader` là một đối tượng chứa con trỏ native GPU unmanaged. Trong hàm `dispose()` của cả hai widget `AuroraBgLayer` và `NeonAuraLayer`, chỉ có `_ticker.dispose()` được gọi mà thiếu `_shader?.dispose()`. Khi người dùng mở và đóng các màn hình có hiệu ứng này nhiều lần trong một phiên chơi, các native shader instances sẽ tích tụ liên tục trong bộ nhớ GPU, gây nóng máy và sập ứng dụng (OOM).
- **Cách khắc phục:** Thêm `_shader?.dispose();` vào phương thức `dispose()` của cả 2 State class.

---

### 1.5. [Nguy cơ Sập Ứng dụng & Vi phạm Chính sách Google Play] Dùng `exactAllowWhileIdle` mà không kiểm tra quyền
- **Vị trí:** `lib/core/reminder_service.dart:48`
- **Mô tả lỗi:** Gọi `androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle`. Kể từ Android 12 (API level 31+), việc lên lịch thông báo dạng Exact Alarm mà không khai báo quyền `SCHEDULE_EXACT_ALARM` hoặc `USE_EXACT_ALARM` trong `AndroidManifest.xml` sẽ ném ngoại lệ `SecurityException` làm crash app. Ngoài ra, Google Play cấm các ứng dụng casual game thông thường sử dụng exact alarm trừ khi có giải trình hợp lý. Đối với game nhắc nhở quay lại chơi (retention reminder), chế độ `exact` là hoàn toàn không cần thiết. Đồng thời, app chưa có hàm xin quyền `POST_NOTIFICATIONS` cho Android 13+.
- **Cách khắc phục:** Đổi sang `AndroidScheduleMode.inexactAllowWhileIdle` hoặc `AndroidScheduleMode.inexact`, đồng thời bổ sung hàm `requestPermission()` cho iOS và Android 13+.

---

### 1.6. [Ghi đè Toàn cục / Hỏng Asset của Consuming App] Hardcode Prefix của `FlameAudio`
- **Vị trí:** `lib/core/audio_manager.dart:24`
- **Mô tả lỗi:** `FlameAudio.audioCache.prefix = 'packages/roy_casual_kit/asset/audio/';`. Dòng lệnh này ghi đè thuộc tính tĩnh toàn cục `prefix` của toàn bộ hệ thống `FlameAudio`. Khi một dự án game khác import package `roy_casual_kit` và muốn phát âm thanh riêng từ thư mục asset của app đó (ví dụ `assets/audio/sfx_tap.mp3`), `FlameAudio` sẽ tìm sai đường dẫn vào bên trong package `roy_casual_kit` và báo lỗi không tìm thấy file.
- **Cách khắc phục:** Tách `AudioCache` riêng biệt cho package hoặc cho phép truyền `audioPrefix` tùy chỉnh từ cấu hình khởi tạo của ứng dụng.

---

### 1.7. [Nguy cơ Phá hủy BGM Player Dùng chung] `_ignoreAudio` tự động dispose `AudioPlayer`
- **Vị trí:** `lib/core/audio_manager.dart:76-91`
- **Mô tả lỗi:** Trong hàm `_ignoreAudio`, đoạn code `if (value is AudioPlayer) { ... whenComplete(value.dispose) }` sẽ tự động giải phóng đối tượng player. Nếu một phương thức gọi nhạc nền trả về instance của player nội bộ mà `FlameAudio.bgm` đang dùng chung, việc dispose player này sẽ khiến toàn bộ các lệnh play/resume BGM tiếp theo bị lỗi tê liệt.
- **Cách khắc phục:** Chỉ dispose các instance `AudioPlayer` được tạo riêng cho hiệu ứng one-shot SFX ngắn hạn, không can thiệp vào lifecycle của BGM stream player.

---

### 1.8. [Lỗi Bất đồng bộ trong Hàm Đồng bộ] `nowMsClamped` & `todayEpochDayClamped` gọi Future không await
- **Vị trí:** `lib/core/utils/clamped_clock.dart:28, 39`
- **Mô tả lỗi:** `StorageService.to.setInt(...)` là một hàm `Future<void>`, nhưng được gọi bên trong các hàm đồng bộ `nowMsClamped()` và `todayEpochDayClamped()` mà không có `unawaited(...)` hoặc xử lý lỗi bắt ngoại lệ bất đồng bộ.
- **Cách khắc phục:** Sử dụng `unawaited(StorageService.to.setInt(...))` hoặc chuyển sang dùng bộ đệm `setIntBuffered` để đảm bảo an toàn luồng và tuân thủ lint rules.

---

### 1.9. [Lỗi Ràng buộc Widget Tree] `LoadingOverlay` trực tiếp trả về `Positioned.fill`
- **Vị trí:** `lib/presentation/widgets/common/loading_overlay.dart:22`
- **Mô tả lỗi:** `LoadingOverlay.build` trả về trực tiếp `Positioned.fill(...)`. Trong Flutter, `Positioned` bắt buộc phải là con trực tiếp của một `Stack`. Nếu lập trình viên vô tình đặt `LoadingOverlay` bên trong `Container`, `Center`, `Column` hoặc trả về từ một custom widget builder, Flutter sẽ ném lỗi đỏ màn hình: *"Incorrect use of ParentDataWidget: Positioned widgets must be placed directly inside Stack widgets."*
- **Cách khắc phục:** Biến `LoadingOverlay` thành một container full-screen bình thường (`SizedBox.expand` với `ModalBarrier` / dimmed container) hoặc cung cấp cả 2 dạng: widget thường và `PositionedLoadingOverlay`.

---

### 1.10. [Rủi ro Xung đột & Ticker Exception] `ToastBanner.show` phụ thuộc Navigator vsync và không có hàng đợi
- **Vị trí:** `lib/presentation/widgets/common/toast_banner.dart:67-105`
- **Mô tả lỗi:** 
  1. `ToastBanner.show` sử dụng `vsync: Navigator.of(context)` cho `AnimationController`. Nếu màn hình hiện tại bị đóng trước khi hết thời gian chờ `Future.delayed(duration)`, controller sẽ reverse trên một `TickerProvider` đã bị hủy, gây exception.
  2. Khi người dùng bấm liên tục (hoặc nhiều sự kiện bắn ra cùng lúc), nhiều `OverlayEntry` được chèn chồng chéo lên cùng một vị trí pixel trên màn hình, gây lỗi hiển thị xấu xí.
- **Cách khắc phục:** Lưu trữ static instance của toast đang hiển thị để hủy toast cũ trước khi hiện toast mới, đồng thời kiểm tra `mounted` và trạng thái animation trước khi thao tác controller.

---

### 1.11. [Thiếu Chuẩn Package Flutter] Thiếu file Entry Point Root `lib/roy_casual_kit.dart`
- **Vị trí:** Thư mục gốc `lib/`
- **Mô tả lỗi:** Theo chuẩn thiết kế Flutter Package của pub.dev, mọi package phải có một file barrel trùng tên package ở gốc thư mục `lib/` (tức `lib/roy_casual_kit.dart`). Hiện tại thư mục `lib/` chỉ có 2 thư mục con `core/` và `presentation/`, buộc consuming app phải import thủ công từng file rời rạc.
- **Cách khắc phục:** Tạo file `lib/roy_casual_kit.dart` export tất cả các public classes trong `core` và `presentation`.

---

### 1.12. [Thiếu Tính Phản Ứng Runtime] `NeonTheme.dark` là biến static thường không tự kích hoạt Rebuild
- **Vị trí:** `lib/core/neon_theme.dart:16`
- **Mô tả lỗi:** `static bool dark = false;` không phải là `RxBool` của GetX, cũng không sử dụng `InheritedWidget` hay `ThemeExtension`. Khi người dùng chuyển đổi Dark/Light mode trong lúc chơi, các widget đang hiển thị sẽ không tự cập nhật lại màu sắc mới nếu không có lệnh ép rebuild toàn bộ app (`Get.forceAppUpdate()`).
- **Cách khắc phục:** Chuyển sang `static final RxBool dark = false.obs;` hoặc tích hợp với hệ thống `ThemeData` / `ThemeExtension` của Flutter.

---

## 2. CÁC TÍNH NĂNG ĐÃ CÓ NHƯNG CẦN ENHANCE (Cải Tiến Chất Lượng)

### 2.1. Hệ thống Audio (`AudioManager`)
- **Tách biệt 2 kênh BGM và SFX:** Hiện tại chỉ có 1 kênh BGM và 1 cờ `muted` chung. Cần tách thành 2 cờ riêng biệt `bgmMuted` và `sfxMuted`.
- **Thanh trượt âm lượng độc lập:** Bổ sung thanh chỉnh âm lượng `bgmVolume` (0.0 - 1.0) và `sfxVolume` (0.0 - 1.0), lưu trữ tự động vào `StorageService`.
- **Audio Pool cho SFX:** Cung cấp hàm `playSfx(String name)` hỗ trợ audio pooling để phát các âm thanh ngắn lặp lại nhanh (click nút, nổ combo, đếm coin) mà không bị drop frame hay delay.
- **Chuyển bài mượt mà (Cross-fade BGM):** Hỗ trợ chuyển đổi nhạc nền giữa màn hình Menu và màn hình Chơi game có hiệu ứng mờ âm lượng dần (fade out / fade in).

### 2.2. Hệ thống Lưu trữ & Hiệu năng (`StorageService`)
- **Hoàn thiện đầy đủ các hàm Buffer:** Bổ sung `setBoolBuffered`, `setDoubleBuffered`, và `setJsonBuffered` để đồng bộ với logic kiểm tra kiểu dữ liệu trong hàm `flush()`.
- **Save Game Migration & Schema Versioning:** Thêm cơ chế quản lý phiên bản dữ liệu lưu (ví dụ `storageVersion`). Khi game cập nhật phiên bản mới có cấu trúc dữ liệu mới, hệ thống tự động chạy hàm migration tương ứng để tránh mất dữ liệu người chơi cũ.
- **Bảo vệ toàn vẹn dữ liệu (Anti-tamper Checksum):** Thêm cơ chế sinh mã hash kiểm tra (HMAC / Checksum) cho file save để phát hiện và ngăn chặn người dùng sửa file local storage nhằm gian lận tiền/vàng.

### 2.3. Widget Đếm Tiền & Điểm Số (`CurrencyCounter`)
- **Tích hợp Bộ Format Số Chuẩn Game:** Hiện tại chỉ hiển thị số nguyên thô `$n`. Cần tích hợp định dạng số lớn kiểu game casual/idle: rút gọn `1.5K`, `2.4M`, `10.8B`, `99T`, `aa`, `ab`... và tự động áp dụng dấu phẩy/chấm theo ngôn ngữ (`fmtNum`).
- **Hiệu ứng Punch Scale (Nảy số):** Khi giá trị tiền tăng lên, toàn bộ widget co dãn nhẹ (scale bump 1.0 -> 1.2 -> 1.0) để tạo cảm giác nhận thưởng sinh động.

### 2.4. Widget Đánh Giá Sao & Tiến Độ (`StarRating` & `ProgressBarStars`)
- **Reactive Update Animation:** Cập nhật `StarRating` hỗ trợ `didUpdateWidget` để khi số sao tăng lên (ví dụ từ 0 lên 3 sao khi kết thúc màn), từng ngôi sao lần lượt bung nở (staggered pop-in) kèm hiệu ứng phát sáng.
- **Xử lý An toàn Kích thước Layout:** Trong `ProgressBarStars`, bảo vệ vị trí của ngôi sao không bị lỗi khi nằm trong môi trường không giới hạn chiều ngang (`unconstrained width` / `Row`).

### 2.5. Hệ thống Rung Phản Hồi (`Haptics`)
- **Mở rộng Mẫu Rung cho Game (Custom Haptic Patterns):** Thay vì chỉ có 3 mức `light`, `medium`, `heavy`, bổ sung các phương thức rung theo ngữ cảnh game:
  - `comboHaptic(int streak)`: Cường độ và tần số rung tăng dần theo chuỗi combo.
  - `warningHaptic()`: Rung kép ngắt quãng khi sắp hết giờ / hết lượt đi.
  - `successHaptic()`: Mẫu rung nhịp điệu ăn mừng chiến thắng.

### 2.6. Hệ thống Thông báo Cục bộ (`ReminderService`)
- **Hỗ trợ Đa Lịch trình Thông báo (Multi-notification Scheduler):** Cho phép đặt nhiều thông báo theo các mục đích khác nhau với ID và Channel riêng biệt:
  - Thông báo hồi đầy tim/năng lượng (Energy Full).
  - Thông báo quà tặng hàng ngày (Daily Reward Ready).
  - Thông báo sự kiện cuối tuần (Weekend Tournament).
- **Hỗ trợ Thông báo Lặp lại (Periodic Notifications):** Tự động đặt lịch nhắc nhở hàng ngày vào đúng khung giờ vàng của người chơi (ví dụ 20:00 mỗi tối).

### 2.7. Trình Chụp & Chia Sẻ Ảnh (`share_helper.dart`)
- **Hỗ trợ `sharePositionOrigin` An toàn trên iPad/Desktop:** Bổ sung tham số vị trí góc neo (anchor Rect) để lệnh chia sẻ không bị crash trên iPadOS và macOS.
- **Template Card Chia sẻ Đẹp Mắt:** Tự động ghép thêm khung avatar, tên người chơi, số điểm kỷ lục, logo game và QR code tải app vào tấm ảnh trước khi chia sẻ lên mạng xã hội.

---

## 3. CÁC TÍNH NĂNG MỚI NÊN THÊM CHO 1 BASE GAME KIT (Casual / Idle Game)

Để `roy_casual_kit` trở thành một bộ khung toàn diện (all-in-one foundation) cho mọi game casual và idle, các tính năng cốt lõi sau cần được bổ sung:

### 3.1. Hệ thống Quản lý Năng lượng / Tim Chơi (Energy & Lives System)
- **Cơ chế:** Tự động đếm ngược hồi phục 1 đơn vị năng lượng sau mỗi $X$ phút (ví dụ 20 phút/1 tim, tối đa 5 tim).
- **Tính năng:**
  - Tự động tính toán số tim hồi phục trong khoảng thời gian người chơi tắt app (dựa trên `ClampedClock`).
  - Widget hiển thị icon Tim kèm timer đếm ngược `"14:25"` và hiệu ứng `"Full"`.
  - Cung cấp hàm tiêu thụ năng lượng khi bắt đầu chơi (`consumeEnergy()`), tặng tim vô hạn trong khoảng thời gian (`grantInfiniteLives(Duration)`).

### 3.2. Bộ Tính Toán Thu Nhập Treo Máy (Offline Progression / Idle Earnings Calculator)
- **Cơ chế:** Dành riêng cho thể loại Idle Game / Tycoon.
- **Tính năng:**
  - Tự động tính toán: `Thu nhập Offline = Thời gian Offline (giới hạn Max Cap) * Tốc độ sản xuất tài nguyên/giây`.
  - Popup chào mừng quay lại `"Welcome Back!"` hiển thị số tiền kiếm được khi vắng mặt, kèm nút `"Claim x1"` và `"Claim x2 (Xem Quảng cáo)"`.

### 3.3. Hệ thống Điểm Danh Hàng Ngày (Daily Login & Streak Calendar)
- **Cơ chế:** Vòng tuần hoàn điểm danh 7 ngày hoặc 30 ngày.
- **Tính năng:**
  - Controller kiểm tra ngày đăng nhập liên tiếp (dùng monotonic epoch day chống tua giờ).
  - Widget giao diện Lịch 7 ngày phong cách Candy với các ô quà: Đã nhận (Claimed với dấu check), Sẵn sàng nhận hôm nay (Claimable với hiệu ứng rung/sáng), và Chưa mở khóa (Locked).
  - Quà ngày thứ 7 dạng Rương Vàng khổng lồ (Mega Chest).

### 3.4. Quản lý Đa Loại Tiền Tệ & Giao Dịch An Toàn (In-Game Economy Ledger)
- **Cơ chế:** Quản lý tập trung các loại tài nguyên trong game: `Coins` (Tiền mềm), `Gems` (Tiền cao cấp), `Stars` (Sao nâng cấp), `Keys` (Chìa khóa mở rương).
- **Tính năng:**
  - Cung cấp phương thức giao dịch an toàn (Transaction): `spend(currency, amount)` tự động kiểm tra số dư, trừ tiền, trả về `bool` và rollback nếu có lỗi.
  - Tự động bắn sự kiện `onBalanceChanged` để cập nhật đồng loạt mọi widget hiển thị trên UI.

### 3.5. Hiệu Ứng Bay Tài Nguyên (Flying Resource Particles / Coin Fly FX)
- **Cơ chế:** Khi người chơi nhận thưởng từ nhiệm vụ hoặc mở rương, sinh ra 10 - 20 đồng xu/kim cương bay từ vị trí bấm thưởng theo đường cong Bezier về đúng vị trí `CurrencyCounter` trên thanh App Bar.
- **Tính năng:**
  - Đích đến tự động khớp theo `GlobalKey` của widget đích.
  - Đồng bộ âm thanh leng keng (coin pickup SFX) và làm nảy số tiền khi từng đồng xu chạm đích.

### 3.6. Hệ thống Nhiệm Vụ & Thành Tựu (Quest & Achievement Engine)
- **Cơ chế:** Quản lý danh sách Nhiệm vụ hàng ngày (Daily Quests) và Thành tựu trọn đời (Achievements).
- **Tính năng:**
  - Cơ chế đếm tiến độ: `incrementProgress(questId, amount)`.
  - Tự động kiểm tra hoàn thành (`isCompleted`), phát hiệu ứng thông báo Toast/Badge khi hoàn thành nhiệm vụ.
  - Widget danh sách nhiệm vụ đi kèm thanh tiến độ mini và nút `"Claim Reward"`.

### 3.7. Luồng Đánh Giá App & Cập Nhật (In-App Review & Update Flow)
- **Cơ chế:** Tự động kích hoạt hộp thoại xin đánh giá 5 sao vào "khoảnh khắc vui vẻ" (Happy Moment - ví dụ vừa thắng liên tiếp 3 màn hoặc vừa nâng cấp thành công).
- **Tính năng:**
  - Tích hợp chuẩn Google In-App Review / iOS StoreKit.
  - Widget Dialog `"Rate Us"` phong cách Candy hỏi thăm trước độ hài lòng của người chơi.

---

## 4. CÁC Ý TƯỞNG ĐỘC ĐÁO & TÍNH NĂNG ĐỘC QUYỀN (TẠO LỢI THẾ CẠNH TRANH)

Để `roy_casual_kit` không chỉ là một base template thông thường mà trở thành một **"Vũ khí Tối thượng"** giúp các studio game indie và casual tăng tốc độ phát triển sản phẩm (giảm 70% thời gian làm UI/Core), kit nên có các tính năng độc quyền sau:

```
+-----------------------------------------------------------------------------------+
|                        ROY CASUAL KIT - EXCLUSIVE FEATURES                        |
+-----------------------------------------------------------------------------------+
|  1. "Juice & Game-Feel" Engine      --> Biến mọi cú chạm thành trải nghiệm sướng tay |
|  2. Adaptive Procedural Audio Mix   --> Âm thanh biến đổi cao độ theo chuỗi combo |
|  3. Flame-GetX Reactive Bridge     --> Gắn Flutter UI dính chặt vào nhân vật Flame|
|  4. Live Designer HUD Playground   --> Chỉnh sửa UI/Particle/Shader trực tiếp     |
|  5. Smart NTP Anti-Time-Travel     --> Chống tua giờ không cần bắt người chơi online |
|  6. Viral Infographic Share Card   --> Tự động tạo ảnh poster chiến thắng đẹp mắt  |
+-----------------------------------------------------------------------------------+
```

### 4.1. "Juice" & "Game-Feel" Micro-Interaction Framework
> *Trong thiết kế game, "Juice" là thuật ngữ chỉ các hiệu ứng phản hồi thị giác và xúc giác tạo cảm giác "đã tay, sướng mắt" cho người chơi.*

- **Squash & Stretch Physical Wrapper:** Một widget wrapper tự động tạo độ biến dạng co dãn đàn hồi kiểu hoạt hình khi người dùng chạm vào (nhấn xuống dẹt ra, buông tay bung cao) dựa trên mô phỏng vật lý lò xo (Spring simulation).
- **Screen Shake Controller:** Hiệu ứng rung giật màn hình toàn cục có thể điều chỉnh độ mạnh (`intensity`), tần số và thời gian suy giảm (`decay`), dùng cho các pha ăn combo lớn, bom nổ hoặc thất bại.
- **Combo Heat Reactive Background:** Bộ shader nền tự động chuyển màu từ gam dịu sang bốc lửa rực rỡ (tăng tốc độ hạt và độ phát sáng) tương ứng theo chỉ số `energyOf` của combo trong game.

### 4.2. Hệ thống Âm Thanh Tương Tác Theo Nhịp Game (Adaptive Procedural Jingle Engine)
- **Thang âm Combo Tăng dần (Ascending Pitch Pop):** Khi người chơi thực hiện chuỗi hành động liên tiếp (ví dụ nổ kẹo x1, x2, x3, x4, x5...), SFX tự động tăng dần cao độ theo thang âm ngũ cung (Do - Re - Mi - Fa - Sol - La - Si - Do cao), tạo cảm giác phấn khích tột cùng.
- **Dynamic Tension Music (Âm nhạc căng thẳng):** Tự động đẩy nhanh nhịp độ (BPM/Tempo) của bài BGM khi đồng hồ đếm ngược của màn chơi còn dưới 10 giây.
- **Audio Ducking tự động:** Tự động giảm âm lượng BGM xuống 30% khi có âm thanh chúc mừng chiến thắng (Victory Fanfare) hoặc khi mở Dialog hướng dẫn.

### 4.3. Cầu Nối Đồng Bộ Tọa Độ Flame & Flutter UI (Unified Flame-GetX Reactive Bridge)
- **Vấn đề thị trường:** Các game kết hợp Flutter và Flame thường gặp khó khăn khi muốn hiển thị các widget Flutter (như bong bóng hội thoại, thanh máu HP bar, số damage nhảy lên) bay bám dính theo các thực thể game trong Flame Canvas.
- **Giải pháp Độc quyền:** Cung cấp component `FlameTrackedOverlay`:
  - Tự động chuyển đổi tọa độ thực thế giới trong game (`Vector2` của Flame) thành tọa độ màn hình Flutter pixel (`Offset`).
  - Cho phép gắn bất kỳ widget Flutter nào (như `TooltipBubble`, `CurrencyCounter`) bay bám dính chính xác vào vị trí nhân vật trong game 2D mà không bị giật lag hay lệch tỉ lệ màn hình.

### 4.4. Bộ Công Cụ Tinh Chỉnh Trực Tiếp Cho Game Designer (Live In-Game Designer Playground)
- **Khái niệm:** Cung cấp một Drawer bí mật (chỉ mở khi lắc máy hoặc bấm debug) dành riêng cho Artist / Game Designer:
  - **Live Slider:** Cho phép chỉnh trực tiếp trên máy: độ bo góc nút bấm, độ dày viền stroke, cường độ phát sáng neon (`glow intensity`), tốc độ hạt rơi, màu sắc gradient.
  - **Export to Code:** Nút bấm 1-click để xuất toàn bộ thông số vừa chỉnh thành mã nguồn Dart hoặc file `tokens.json` để đưa ngay vào mã nguồn dự án.

### 4.5. Cơ Chế Chống Gian Lận Tua Giờ Thông Minh (Smart Anti-Time-Travel with Monotonic Uptime)
- **Vấn đề của Clamped Clock hiện tại:** Nếu người chơi vô tình chỉnh lịch điện thoại nhảy cóc 10 năm về tương lai và mở app 1 lần, `maxMsSeen` bị chốt ở 10 năm sau, khiến người chơi bị khóa vĩnh viễn tính năng điểm danh và hồi năng lượng.
- **Giải pháp Độc quyền:**
  - Kết hợp 3 nguồn đo lường: `Device Clock`, `System Monotonic Uptime` (thời gian máy chạy liên tục không bị ảnh hưởng bởi việc đổi ngày giờ trong Settings), và `NTP Network Timestamp` âm thầm khi có kết nối mạng.
  - Phát hiện hành vi tua giờ bất thường để đưa ra cảnh báo hoặc khóa tính năng tạm thời thay vì làm hỏng vĩnh viễn file save của người chơi.

### 4.6. Trình Tạo Poster Chiến Thắng Lan Tỏa (Viral Infographic Victory Card Generator)
- **Khái niệm:** Biến tính năng chia sẻ kết quả thông thường thành công cụ quảng bá lan truyền (Viral Marketing):
  - Tự động tạo ảnh poster chiến thắng với layout đồ họa bắt mắt: Avatar người chơi, Cúp chiến thắng, Thống kê ấn tượng (*"Bạn vừa vượt qua màn 50 nhanh hơn 92% người chơi khác!"*), kèm khung trang trí theo sự kiện và mã QR có deep link tải game nhận quà cho bạn bè.

---

## 5. TỔNG KẾT & LỘ TRÌNH ĐỀ XUẤT

```
   GIAI ĐOẠN 1 (Ngay lập tức)      GIAI ĐOẠN 2 (Ngắn hạn)          GIAI ĐOẠN 3 (Đột phá)
+-------------------------------+-------------------------------+-------------------------------+
| * Sửa lỗi ConfirmDialog Back  | * Tách kênh BGM / SFX         | * "Juice" & Screen Shake FX   |
| * Thêm key back_button_label  | * Bổ sung Hệ thống Năng lượng | * Flame-GetX Reactive Bridge  |
| * Fix rò rỉ GPU Shader memory | * Hệ thống Điểm danh 7 ngày   | * Live Designer Playground    |
| * Sửa format thời gian fmtDur | * Bộ tính toán Idle Offline   | * Adaptive Procedural Audio   |
| * Tạo entry lib/roy_casual_kit| * Hiệu ứng Bay Tiền (Coin Fly)| * Viral Share Card Generator  |
+-------------------------------+-------------------------------+-------------------------------+
```

Package `roy_casual_kit` sở hữu nền tảng thiết kế UI phong cách Candy-Neon rất đẹp mắt, tinh gọn và hướng đối tượng rõ ràng. Sau khi khắc phục các lỗi về vòng đời/bộ nhớ ở Mục 1 và nâng cấp các tính năng cốt lõi ở Mục 2 & 3, package sẽ hoàn toàn đủ tiêu chuẩn trở thành một trong những Game Base Kit tốt nhất trong hệ sinh thái Flutter Game!
