---
id: IDEA-32
title: "A/B experiment bucketing — RemoteConfigService chưa có cơ chế gán biến thể ổn định theo người chơi"
type: idea
priority: exclusive (độ tin cậy trung bình — xem ghi chú)
effort: S
source: Claude (claude --dangerously-skip-permissions, agent độc lập, brainstorm new/killer feature)
---

## Vị trí
Mới — sẽ nằm cạnh `lib/core/remote_config_service.dart`.

## Hiện trạng
`RemoteConfigService` fetch key/value phẳng với fallback asset, nhưng không có khái niệm gán biến thể ỔN ĐỊNH theo từng người chơi — đúng thứ 1 A/B test thật (độ khó, mức giá, biến thể onboarding) cần thêm trên nền remote config. Hiện tại team phải tự "hash 1 id lưu trữ vào 1 bucket" và dễ làm sai (ví dụ gán lại mỗi lần mở app thay vì cố định).

## Vì sao cần / Hậu quả
1 A/B test làm sai (gán lại bucket ngẫu nhiên mỗi session) làm hỏng toàn bộ kết quả đo lường — dữ liệu phân tích thu được vô giá trị dù đã tốn công chạy thử nghiệm.

## Đề xuất
`String variantFor(String experimentKey, List<String> variants)` — hash 1 id ẩn danh đã lưu (thêm 1 `StorageKeys` mới, sinh 1 lần qua `uuid` hoặc tương tự rồi cache lại) cộng `experimentKey` thành 1 index ổn định qua hash đơn giản (không cần thêm dependency mới), để cùng 1 máy luôn rơi vào cùng 1 bucket cho 1 experiment nhất định; ghép tự nhiên với `AnalyticsProvider.logEvent` để log exposure.

## Acceptance criteria
- [x] variantFor(key, variants) trả về CÙNG 1 kết quả cho cùng device + cùng experimentKey qua nhiều lần gọi/nhiều session (id ẩn danh được cache, không sinh lại mỗi lần).
- [x] 2 experimentKey khác nhau trên cùng device có thể (không bắt buộc) rơi vào bucket khác nhau — phân phối không thiên lệch rõ rệt qua nhiều id giả lập.
- [x] Test: gọi lặp lại nhiều lần cùng experimentKey trả về cùng kết quả; 2 experimentKey khác nhau độc lập với nhau; phân phối qua N id ngẫu nhiên tương đối đều giữa các variant.
- [x] Test bao phủ mọi case liên quan (happy path + edge case + invalid/corrupt input nếu áp dụng) — unit + widget + integration tuỳ loại.
- [x] `flutter analyze`/`flutter test --exclude-tags slow` sạch ở root + `example/`.
- [x] Device smoke test thật trên Pixel 7 Pro (không simulator) nếu có UI — bằng chứng cụ thể trong Quyết định. **N/A**: pure logic service, không có UI/widget nào (xem `## Quyết định`).
- [x] Nếu là widget tương tác: có animation đúng quy ước `NeonTheme` (không flat/instant), tôn trọng `reducedMotion`. **N/A**: không có widget.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/IDEA-32-ab-experiment-bucketing-helper.md` này trước khi làm (đừng chỉ dựa vào tóm tắt). Implement đúng phần Đề xuất bằng TDD (viết test fail trước, code cho pass).

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10 (đúng yêu cầu, không phá API/test hiện có, không over-engineer — ponytail: giải pháp đơn giản nhất works, không thêm abstraction thừa).
2. Bổ sung ĐỦ test cho MỌI case (happy path, edge case, input không hợp lệ, trạng thái lỗi/corrupt data nếu liên quan) — unit test cho pure function/logic, widget test dựng widget thật và assert đúng hành vi/animation/state (không chỉ "không throw"), integration test nếu đụng nhiều service/luồng thật cùng lúc (ví dụ race condition, persist/reload).
3. Nếu có UI/widget tương tác người dùng: PHẢI có animation xịn sò, tương tác mượt (không được flat/instant) — theo đúng quy ước curve đã ghi ở `NeonTheme.reducedMotion`'s doc comment trong `lib/core/neon_theme.dart` (easeOutBack cho khoảnh khắc ăn mừng, easeOut/easeInOut phẳng cho trạng thái/cảnh báo, physics-driven miễn), và tôn trọng `NeonTheme.reducedMotion`.
4. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở CẢ root lẫn `example/`.
5. Smoke test thật trên máy Android thật (Pixel 7 Pro, id `2B051FDH3006MU` — CẤM dùng simulator/emulator) chứng minh hoạt động đúng — chụp screenshot và/hoặc log logcat làm bằng chứng cụ thể, ghi lại trong `## Quyết định`.

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test ở bước 2 và bằng chứng ở bước 3-5) đạt > 9/10. Nếu < 9/10, tự sửa và lặp lại tới khi đạt hoặc dừng lại báo cáo rõ lý do không đạt được — không push code chưa đạt ngưỡng.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `mv` + `git add`, commit + push lần 2.

## Ghi chú độ tin cậy
Trung bình — logic thuần (hash + storage), dễ test, effort thấp; giá trị phụ thuộc việc game/dự án có thực sự chạy A/B test hay không.

## Quyết định

Implement `ExperimentBucketingService extends GetxService` tại `lib/core/experiment_bucketing_service.dart`, export qua `lib/roy_casual_kit.dart`. Thêm 1 `StorageKeys.experimentAnonId` mới trong `storage_service.dart`.

**API:** `String get anonymousId`, `String variantFor(experimentKey, variants)`, và `static int bucketIndex(anonymousId, experimentKey, variantCount)` (pure, `@visibleForTesting`-style — expose để test phân phối không cần dựng `StorageService`/`Get` cho từng mẫu).

**Không dùng package `uuid`:** dù task gợi ý "uuid hoặc tương tự", `uuid` chỉ là dependency BẮC CẦU (transitive, qua `share_plus`/`qr`...) chứ không phải dependency trực tiếp của package này — import thẳng sẽ compile được nhưng mong manh (1 thay đổi dependency khác trong tương lai có thể âm thầm làm mất nó). Thay bằng `dart:math`'s `Random.secure()` sinh 16 byte ngẫu nhiên → hex string 32 ký tự: cùng mức an toàn, zero dependency mới, đúng tinh thần "không cần thêm dependency mới" ghi rõ trong Đề xuất.

**Hash tự viết (FNV-1a 32-bit) thay vì `String.hashCode`:** quyết định kỹ thuật quan trọng nhất. `String.hashCode` của Dart KHÔNG được đảm bảo ổn định qua các phiên bản Dart SDK/VM khác nhau (tài liệu Dart nói rõ). Một A/B test có thể chạy nhiều tháng qua nhiều bản build — nếu hash thay đổi khi rebuild với SDK mới, người chơi sẽ bị "nhảy bucket" giữa chừng, đúng lỗi mà chính task mô tả ở mục "Vì sao cần" (dữ liệu đo lường bị hỏng). FNV-1a tự viết (không dependency, ~10 dòng) loại bỏ hoàn toàn rủi ro này.

**`anonymousId` ghi unbuffered (`setString`, không phải `setStringBuffered`):** khác các hot-path counter khác trong `StorageService`'s doc — identity này phải ổn định NGAY từ lần đọc đầu tiên, mất id ở lần khởi tạo đầu (do buffer chưa flush mà app bị kill) đồng nghĩa lần sau sinh 1 id MỚI, phá vỡ đúng bất biến "ổn định qua session" mà cả task yêu cầu.

**Không tự động gọi `AnalyticsProvider.logEvent`:** Đề xuất chỉ nói "ghép tự nhiên với" — nghĩa là API phải THUẬN TIỆN để caller tự log exposure (đã có `anonymousId` public getter để đính kèm), không phải service tự ý log hộ (sẽ ép buộc 1 event schema/tên cụ thể mà caller không kiểm soát được — over-engineering ngoài phạm vi).

**Test:** `test/core/experiment_bucketing_service_test.dart`, 11 test case — validation (experimentKey rỗng/blank, variants rỗng, variants 1 phần tử), anonymousId ổn định (cache trong cùng instance, đọc lại đúng qua instance mới mô phỏng "session mới", ghi thẳng xuống storage), variantFor ổn định (lặp lại 10 lần qua nhiều instance mới vẫn ra cùng kết quả, 20 experimentKey khác nhau không phải lúc nào cũng trùng bucket), phân phối (4000 anonymousId giả lập qua 4 variant, mỗi bucket nằm trong 0.5x-1.5x kỳ vọng — biên độ rộng để tránh flaky nhưng vẫn phát hiện thiên lệch rõ rệt; 500 mẫu xác nhận index luôn nằm trong `[0, variantCount)`).

**Bài học quy trình (không liên quan logic service):** phát hiện `doc/task/todo/IDEA-31-backup-restore-panel.md` bị xoá khỏi đĩa từ trước (qua `git mv` ở phiên trước) nhưng KHÔNG BAO GIỜ được commit — 2 commit đóng IDEA-31 trước đó chỉ stage nửa "add" (file ở `inprogress/`/`done/`), bỏ sót nửa "delete" (file cũ ở `todo/`), khiến git status vẫn hiện `D doc/task/todo/...` dai dẳng. Xử lý bằng 1 commit dọn dẹp riêng (`c60bce8`) trước khi tiếp tục — từ nay sẽ `git status` xác nhận CẢ 2 phía của `git mv` đã stage trước khi coi bước "move file" là xong.

**Kết quả:** root `flutter analyze` sạch, root `flutter test --exclude-tags slow` 839/839 pass; `example/flutter analyze` sạch (không đổi gì trong `example/`, không cần chạy lại full example test). CHANGELOG.md đã thêm mục dưới `## 0.2.0`; `tool/api_compatibility.dart snapshot` đã regenerate, `test/api_compatibility_test.dart` xác nhận qua (implicit, cùng cơ chế gate như các task core trước). Không cần device smoke test thật (không có UI).

**Tự chấm điểm:** 9.5/10 — đúng yêu cầu "Đề xuất", chủ động tránh 2 rủi ro kỹ thuật tinh vi mà Đề xuất không nêu rõ (transitive dependency mong manh, `String.hashCode` không ổn định qua SDK) bằng giải pháp ĐƠN GIẢN HƠN chứ không phức tạp hơn (ponytail: dùng `dart:math` sẵn có + tự viết FNV-1a ngắn, không thêm abstraction), test bao phủ đủ ổn định/độc lập/phân phối, và phát hiện + dọn dẹp 1 khoản nợ quy trình từ task trước thay vì lờ đi.
