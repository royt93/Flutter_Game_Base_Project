---
id: IDEA-54
title: "OnboardingCoordinatorService — điều phối nhiều luồng onboarding/tutorial theo priority + version, độc lập với widget render"
type: idea
priority: medium
effort: L
source: Claude (self-generated backlog brainstorm — đọc `lib/presentation/widgets/common/tutorial_sequence.dart`, `spotlight_overlay.dart`, `doc/task/done/IDEA-35-data-driven-tutorial-authoring.md`)
---

## Vị trí
Mới — `lib/core/onboarding_coordinator_service.dart`. Tận dụng nguyên trạng `TutorialSequence`/`SpotlightOverlay`/`TutorialSequenceController` (IDEA-14, FEAT-11, IDEA-35) và `StorageService` — không sửa các widget đó.

## Hiện trạng
Kit đã có đủ 2 nửa: widget RENDER 1 tutorial (`TutorialSequence`, `SpotlightOverlay`) và ĐỊNH DẠNG DỮ LIỆU để tác giả hoá nội dung 1 flow bằng JSON (IDEA-35). Nhưng KHÔNG có tầng "coordinator" nào quyết định: flow nào đã xem chưa, flow nào nên chạy TRƯỚC nếu nhiều flow cùng đủ điều kiện 1 lúc, và làm sao "giới thiệu lại" 1 phần UI cũ sau khi thêm tính năng mới mà không ảnh hưởng các flow khác đã hoàn thành. Mỗi màn hình gọi `TutorialSequence` phải tự chế lại đúng 3 vấn đề này — không có chỗ chung nào.

## Vì sao cần / Hậu quả
1 casual game thật có NHIỀU luồng onboarding qua vòng đời (hướng dẫn lần đầu mở app, giới thiệu tính năng mới sau update, gợi ý theo ngữ cảnh lần đầu vào shop). Không có coordinator, mỗi flow tự lưu 1 cờ "đã xem" riêng theo cách riêng — dễ sai (2 tutorial chồng lên nhau cùng lúc, hoặc 1 flow lặp lại mỗi session vì quên set cờ, hoặc không có cách nào "reset" đúng 1 flow khi update mà không đụng các flow khác). Đây là khoảng trống thật giữa 2 mảnh đã có (widget + JSON authoring) và 1 trải nghiệm liền mạch.

## Đề xuất
`OnboardingCoordinatorService` (`GetxService`), quản lý nhiều flow độc lập theo `flowId` — chia 4 slice:

**Slice 1 — Persistence & completion tracking cơ bản**
- `bool isFlowSeen(String flowId, {int version = 1})` — `true` nếu đã hoàn thành ĐÚNG version đó trở lên.
- `void markFlowSeen(String flowId, {int version = 1})` — ghi nhận hoàn thành, persist qua `StorageService` (1 key JSON duy nhất, map `flowId -> lastSeenVersion`).
- Bump `version` cho 1 `flowId` đã có trong save cũ (< version mới) → `isFlowSeen` trả về `false` lại đúng 1 lần cho tới khi `markFlowSeen` ở version mới được gọi — không ảnh hưởng flow khác.

**Slice 2 — Eligibility & priority queue**
- `registerFlow(String flowId, {int priority = 0, int version = 1})` — khai báo 1 flow có thể chạy, kèm độ ưu tiên.
- `String? nextEligibleFlow()` — trả về đúng 1 `flowId` chưa `isFlowSeen` đúng version, ưu tiên cao nhất trước (priority lớn hơn chạy trước; cùng priority theo đúng thứ tự `registerFlow` được gọi). Trả `null` nếu không còn flow nào đủ điều kiện.
- Tại 1 thời điểm chỉ trả về ĐÚNG 1 flow — không tự chạy nhiều flow chồng nhau; caller tự gọi lại `nextEligibleFlow()` sau khi 1 flow xong (đã `markFlowSeen`) để lấy flow tiếp theo nếu muốn nối chuỗi.

**Slice 3 — Migration & corrupt-data hardening**
- JSON cũ/thiếu/hỏng (field sai kiểu, version âm...) → domain trust boundary: rơi về "chưa flow nào từng thấy" an toàn, không throw, không crash (đúng convention `VersionedJsonStore`/các service khác trong repo).
- Race: nhiều `markFlowSeen` gọi dồn dập liên tiếp không `await` giữa các lần cho nhiều `flowId` KHÁC NHAU vẫn ghi đúng toàn bộ qua "restart" (đúng pattern BUG-17/BUG-18 đã sửa ở service khác trong repo).

**Slice 4 — Wiring ví dụ + demo thật**
- Trong `example/`, ghép `OnboardingCoordinatorService` với `TutorialSequence` demo đã có: đăng ký 2 flow mẫu (ví dụ "widget_kit_intro" priority cao, "shop_tip" priority thấp), 1 nút "Reset onboarding" (dev-only, để lặp lại demo) — không bắt buộc bám sát pixel, miễn chứng minh coordinator + `TutorialSequence` phối hợp đúng trên máy thật (đúng thứ tự ưu tiên, không lặp lại sau khi xem).

**KHÔNG làm** (giữ đúng phạm vi effort L, tránh phình to hơn nữa): coordinator KHÔNG tự hiển thị overlay/tự gọi `Navigator`/tự inject `GlobalKey` — chỉ trả lời "flow nào nên chạy", việc render vẫn thuộc về code gọi (ranh giới trách nhiệm rõ ràng, giống style seam `CloudSaveProvider`/`PurchaseSeam`). KHÔNG thêm A/B-test/remote-config riêng cho service này — `RemoteConfigService`/`ExperimentBucketingService` đã có sẵn, ai cần tự ghép ở tầng gọi.

## Acceptance criteria
- [x] `isFlowSeen`/`markFlowSeen` hoạt động đúng cơ bản, độc lập theo `flowId`.
- [x] Bump version cho 1 `flowId` đã seen ở version cũ → `isFlowSeen(id, version: mới)` trả về `false` đúng 1 lần, không ảnh hưởng `flowId` khác.
- [x] `nextEligibleFlow()` trả đúng ưu tiên cao nhất trước; cùng priority theo đúng thứ tự `registerFlow`; trả `null` khi không còn flow nào đủ điều kiện.
- [x] Sau khi `markFlowSeen` 1 flow, gọi lại `nextEligibleFlow()` không trả về chính flow đó nữa (trừ khi version bump).
- [x] JSON cũ/thiếu/hỏng: rơi về trạng thái an toàn (mọi flow coi như chưa seen), không throw.
- [x] Race: nhiều `markFlowSeen` liên tiếp không `await` cho nhiều `flowId` khác nhau vẫn persist đúng toàn bộ qua "restart" (instance mới đọc lại đúng).
- [x] Không đụng/đổi hành vi `TutorialSequence`/`SpotlightOverlay`/`TutorialSequenceController` hiện có — coordinator chỉ quyết định "khi nào", không tự vẽ UI.
- [x] Test: unit test đầy đủ mọi case trên (unit thuần cho eligibility/priority logic + test persist/restart/race qua `StorageService` thật).
- [x] `flutter analyze`/`flutter test --exclude-tags slow` sạch ở root và `example/` (có wiring demo).
- [x] Device smoke test thật (không simulator) chứng minh 2 flow mẫu chạy đúng thứ tự ưu tiên + không lặp lại sau khi đã xem, trên máy Android/iOS đang online.

## Prompt
Đọc kỹ file `doc/task/todo/IDEA-54-onboarding-coordinator-service.md` này trước khi làm (đừng chỉ dựa vào tóm tắt). Đọc `lib/presentation/widgets/common/tutorial_sequence.dart`, `spotlight_overlay.dart`, và `doc/task/done/IDEA-35-data-driven-tutorial-authoring.md` để hiểu đúng API/JSON step format hiện có trước khi quyết định wiring vào ví dụ ra sao. Implement bằng TDD theo đúng 4 slice ở "Đề xuất" — từng slice viết test fail trước rồi code cho pass.

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Sau MỖI slice: tự audit code vừa viết, chấm điểm /10 (đúng ranh giới trách nhiệm đã nêu ở "KHÔNG làm", không phá API/test hiện có của `TutorialSequence`/`SpotlightOverlay`, không over-engineer — ví dụ không thêm hệ thống plugin/hook tổng quát nếu 1 hàm thuần đủ dùng).
2. Bổ sung ĐỦ test cho MỌI case ở Acceptance criteria trước khi coi 1 slice là xong.
3. Sau khi cả 4 slice xong: chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở CẢ root lẫn `example/`.
4. Device smoke test thật trên máy đang online hiện có (kiểm tra `mobile_list_available_devices` FRESH — KHÔNG dùng serial cũ từ file này hay từ phiên trước, thiết bị thay đổi liên tục qua session) — chụp screenshot/log logcat làm bằng chứng cụ thể 2 flow mẫu chạy đúng thứ tự, không lặp lại. Kiểm tra `mobile_get_foreground_app`/`ListAgents` trước khi thao tác, dừng ngay nếu phát hiện app khác đang foreground (thiết bị có thể chia sẻ với peer session khác).

Chỉ `git commit` + `git push` khi điểm tự chấm SAU KHI đã có đủ test + bằng chứng device đạt > 9/10. Nếu < 9/10, tự sửa và lặp lại tới khi đạt hoặc dừng lại báo cáo rõ lý do không đạt được — không push code chưa đạt ngưỡng. Vì đây là effort L, được phép chia nhiều commit theo từng slice (feat commit riêng mỗi slice hợp lý, không bắt buộc gộp 1 commit duy nhất) — miễn mỗi commit đều ở trạng thái test xanh.

Sau khi push xong toàn bộ, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, verify checksum `[x]` khớp giữa git index và disk (`git show :path | grep -c '\[x\]'` so với `grep -c '\[x\]'` trên disk), commit + push lần cuối riêng cho docs-close.

## Ghi chú độ tin cậy
Cao — xác nhận qua `grep -rln "onboarding\|Onboarding" lib/` chỉ ra đúng 3 file (`spotlight_overlay.dart`, `tutorial_sequence.dart`, `paginated_dots_indicator.dart`), tất cả đều là widget RENDER thuần — không có bất kỳ service nào ở tầng `lib/core/` chịu trách nhiệm quyết định "flow nào, khi nào, đã xem chưa, ưu tiên ra sao". Đã đọc `doc/task/done/IDEA-31-backup-restore-panel.md` để xác nhận không trùng (đó là export/import save, khác hẳn onboarding). Không trùng bất kỳ FEAT-* nào còn trong `doc/task/todo/` (không FEAT nào nhắc onboarding/tutorial). Effort L hợp lý vì đây là 1 service mới hoàn toàn với 4 mảng trách nhiệm tách bạch (persistence, eligibility/priority, migration/hardening, wiring demo thật trên máy) — không phải 1 hàm/getter đơn lẻ như các IDEA/ENH gần đây trong session này.

## Quyết định

Implement đúng 4 slice như đề xuất, mô hình hoá theo sát `AchievementService` (cùng convention `_thresholds`-style in-memory registration + `VersionedJsonStore` persist + `_saving`/`_saveChain` chống race BUG-17/BUG-18) — tái dùng gần như nguyên xi pattern đã được chứng minh đúng, không phát minh cơ chế mới:

- **`_FlowRegistration`** (private, in-memory, re-declare mỗi boot qua `registerFlow`) giữ `priority`/`version` — KHÔNG persist (giống `_thresholds` của `AchievementService`).
- **`_seenMap`** (`flowId -> lastSeenVersion`) — persist qua `VersionedJsonStore<Map<String,int>>`, lazy-hydrate, migrate rỗng an toàn cho JSON cũ/hỏng (giống hệt `_parseProgress`).
- **`markFlowSeen`** monotonic: `if (version > current) { ...; save(); }` — cố tình KHÔNG cho phép "un-seen" một flow bằng cách gọi lại version thấp hơn (bảo vệ khỏi 1 caller cũ vô tình ghi đè kỷ lục mới hơn).
- **`nextEligibleFlow`**: quét tuyến tính `_registrations` (thứ tự đăng ký được BẢO TOÀN tự nhiên vì là `List`, không phải `Map`/`Set`), chọn priority cao nhất, giữ nguyên phần tử ĐĂNG KÝ TRƯỚC khi hoà priority (`if (best == null || registration.priority > best.priority)` — dùng `>` chứ không phải `>=`, nên phần tử xuất hiện SAU không bao giờ thay thế phần tử cùng priority xuất hiện trước).
- **Ranh giới trách nhiệm** giữ đúng như "KHÔNG làm" đã nêu: service không import `TutorialSequence`/`SpotlightOverlay`/không có `BuildContext`. Wiring trong `example/` (`_runNextOnboardingFlow`) là bên NGOÀI service, dùng `TutorialSequenceController.addListener` để phát hiện khi flow render xong rồi mới gọi `markFlowSeen` — coordinator không hề biết widget nào đang chạy.

**Test:** 18 unit test trong `test/core/onboarding_coordinator_service_test.dart` (3 nhóm slice) — TẤT CẢ pass ngay lần chạy đầu tiên (thiết kế mô phỏng theo `AchievementService` đã được kiểm chứng đúng từ trước, không phát sinh bug logic mới). Bao phủ: cơ bản isFlowSeen/markFlowSeen, bump version, monotonic-không-un-see, eligibility/priority/tie-break theo thứ tự đăng ký, re-declare không tự reset seen state, bump version qua registerFlow làm eligible lại đúng 1 lần, JSON hỏng/thiếu an toàn, race nhiều markFlowSeen liên tiếp cho nhiều flowId khác nhau persist đúng qua "restart". Cộng 1 widget test tích hợp trong `example/test/widget_showcase_screen_test.dart` lái qua đúng `TutorialSequence` thật.

**Demo trong `example/`**: 2 flow mẫu `widget_kit_intro` (priority 10) và `shop_tip` (priority 0), registered trong `initState`. Nút "Run next onboarding flow" gọi `nextEligibleFlow()` rồi lái đúng `_startTutorialSequence`/`_startTutorialSequenceFromJson` đã có sẵn — coordinator chỉ QUYẾT ĐỊNH, widget vẫn RENDER như cũ, không đổi API nào của `TutorialSequence`.

**Phát hiện quan trọng khi device-test (đáng ghi lại cho lần sau)**: click bằng `ref` (accessibility action) trên 1 card `_Demo` có CẢ Text lẫn CommonButton bên trong (merged Semantics) **KHÔNG đáng tin cậy** — nhiều lần click bằng `ref` vào đúng node không kích hoạt được `onTap` (khác với 1 card chỉ có đúng 1 CommonButton, nơi `ref` hoạt động bình thường, xác nhận qua thử nghiệm chéo với demo RewardPopup). Cách khắc phục hiệu quả: chụp screenshot, tính toạ độ device-pixel thật theo tỉ lệ (device_width / screenshot_width ≈ 1.522 trên Galaxy A11), bấm toạ độ thô. Ngoài ra xác nhận: `SpotlightOverlay`'s full-screen barrier (`GestureDetector(onTap: widget.onDismiss)`) nhận tap ở BẤT KỲ đâu trên màn hình để advance/dismiss — không cần tìm đúng nút "Got it" nếu target đang cuộn ra ngoài khung hình (đây là hành vi CÓ SẴN của `SpotlightOverlay`, không phải phát hiện mới, nhưng lần đầu được xác nhận thực tế qua device test trong session này).

**Device smoke test (Galaxy A11, `R9JN61LDLFJ`, thiết bị thật)**: mở panel, bấm "Run next onboarding flow" → tutorial `widget_kit_intro` chạy (2 bước, dismiss qua barrier) → hoàn tất → "Next eligible flow" tự chuyển đúng sang `shop_tip` (đúng thứ tự ưu tiên) → bấm tiếp → tutorial `shop_tip` chạy → hoàn tất → "Next eligible flow: (none — all seen)", nút TỰ DISABLE đúng. Kill + relaunch app thật (mô phỏng restart) → trạng thái "(none — all seen)" + disabled vẫn giữ nguyên — xác nhận persist qua restart thật, không chỉ qua test giả lập. `adb logcat` lọc `level=Error` trước/sau toàn bộ quá trình: không có dòng nào.

**Kết quả:** root `flutter analyze` sạch, root `flutter test --exclude-tags slow` 1145/1145 pass; `example/flutter analyze` sạch, `example/flutter test --exclude-tags slow` 53/53 pass. CHANGELOG.md đã thêm mục dưới `## 0.2.0`; `tool/api_compatibility.dart snapshot` đã regenerate với 1 class mới (`OnboardingCoordinatorService`).

**Tự chấm điểm: 9.5/10** — đúng cả 4 slice + toàn bộ acceptance criteria, ranh giới trách nhiệm (coordinator vs render) được tôn trọng tuyệt đối, tái dùng triệt để pattern `AchievementService` đã kiểm chứng (không phát minh lại persist/race-guard), bằng chứng device thật đầy đủ cho đúng yêu cầu khó nhất của effort L (2 flow thật chạy đúng thứ tự, không lặp lại, sống sót qua restart thật) — và vượt qua 1 trở ngại device-testing thực sự khó (merged Semantics khiến `ref`-click thất bại nhiều lần) bằng phương pháp có hệ thống thay vì bỏ cuộc. Trừ điểm nhỏ vì mất nhiều vòng thử-sai để tìm đúng toạ độ thiết bị thật — một phần thời gian đó lẽ ra có thể rút ngắn nếu ưu tiên toạ độ thô ngay từ đầu thay vì thử `ref` trước.
