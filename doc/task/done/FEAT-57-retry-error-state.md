---
id: FEAT-57
title: "RetryErrorState — error UI chuẩn với retry và diagnostic code"
type: feature
layer: presentation/widget
priority: P0
effort: S
depends_on: [FEAT-38, FEAT-50]
source: user-approved SDK backlog 2026-09-12
---

## User story
Là người dùng, tôi muốn lỗi tải/sync/offline có thông báo và retry nhất quán thay vì màn hình trắng.

## Sprint slices
- Data-driven icon/title/message/code và retry async action.
- Mapping presentation từ typed SDK error, cho phép copy diagnostic code.
- Compact/fullscreen variants, offline action slot và semantics live region.

## Acceptance criteria
- [x] Retry loading/success/failure và rapid tap không chạy trùng.
- [x] User message không lộ exception/secret; diagnostic code ổn định.
- [x] Không có retry callback thì UI không giả tương tác.
- [x] Text scale/RTL/reduced motion và screen reader đạt chuẩn.

## Prompt loop feature
Đọc task/error model; implement TDD. End loop: audit, chấm /10; unit test + widget test + integration test mọi variant/retry/error/accessibility; analyze/test root + example; smoke Android device thật với offline→online proof. Chỉ push khi work và điểm >9/10; cập nhật Quyết định, chuyển done, push lần hai.

## Quyết định

Thêm `RetryErrorState` (`lib/presentation/widgets/common/retry_error_state.dart`) — COMPOSE từ 3 mảnh đã có sẵn thay vì tự dựng UI mới:
- Layout icon-badge/title/message/action tái dùng nguyên `EmptyStatePlaceholder` (đã đúng shape cần, không sửa widget đó).
- Nút Retry dùng thẳng `AsyncCommonButton` (FEAT-50) — "rapid tap không chạy trùng" có MIỄN PHÍ từ guard sẵn có của nó, `RetryErrorState` không tự thêm cơ chế chặn tap nào.
- Diagnostic code hash bằng `fnv1aHash` (có sẵn trong `utils/fnv1a.dart`) trên `'${kind.name}:${message}'` — ổn định tuyệt đối (cùng input luôn cùng code), không dùng `String.hashCode` (không đảm bảo stable qua version Dart, đúng cảnh báo trong doc của chính `fnv1aHash`).
- `fromSdkFailure()` chỉ đọc `SdkFailure.message` (đã là chuỗi an toàn theo doc của chính `SdkFailure`) — KHÔNG BAO GIỜ đụng `.cause`/`.stackTrace`, nên "không lộ exception/secret" đúng theo cấu trúc code chứ không phải theo quy ước phải nhớ tuân thủ.
- Copy diagnostic code: `Clipboard.setData` + `ToastBanner.show` (có sẵn) làm phản hồi trực quan — lần đầu quên pump hết vòng đời animation của ToastBanner trong test gây leak Ticker sang test sau (đã sửa, xem phần Test).
- `compact`/fullscreen chỉ khác nhau ở việc CÓ bọc `Center` hay không — không cần sửa `EmptyStatePlaceholder` để thêm tham số kích thước riêng.
- Bổ sung sau khi review lại Sprint slices: `extraAction` (slot phụ, ví dụ "Open network settings" cho lỗi network — package không biết hành vi cụ thể nên để caller tự truyền Widget, không hardcode 1 nút "offline" có sẵn hành vi) và `Semantics(liveRegion: true)` bọc toàn panel (đúng convention `ToastBanner`/`CurrencyCounter` đã dùng — announce lỗi ngay khi nó thay thế loading/content).

**Test:** `test/widget/common/retry_error_state_test.dart` (14 case, TDD — RED xác nhận trước khi viết `retry_error_state.dart`): hiện icon/title/message, không onRetry thì không có nút, có onRetry rapid-tap chỉ chạy 1 lần, có `extraAction` hiện đúng, có/không code hiện đúng + tap copy vào clipboard (mock `Clipboard.setData`/`getData` qua `SystemChannels.platform`), `fromSdkFailure` map đúng icon/title theo `kind`, diagnostic code ổn định qua 2 lần gọi cùng input, khác input ra code khác, KHÔNG BAO GIỜ lộ `cause` vào message hiển thị, `onRetry` truyền qua đúng, compact không tự bọc `Center`/fullscreen tự bọc, RTL + text scale 2.0 không throw.

Wire demo vào `example/lib/screens/widget_showcase_screen.dart` ("Layout & Cards" section, ngay sau `EmptyStatePlaceholder`) — `RetryErrorState.fromSdkFailure` với 1 `SdkFailure(kind: network)` giả, `onRetry` giả lập delay 800ms, `compact: true`. Việc này đẩy list showcase dài hơn nên phải tăng `physicalSize` cố định trong `widget_showcase_screen_test.dart` (10200→10600) để 1 test cũ (`IDEA-08`, tap "Bump heat" ở cuối list) không bị đẩy ra ngoài viewport ảo — không phải bug code, là bảo trì fixture dùng chung khi thêm demo mới (đã ghi comment giải thích tại chỗ sửa).

**Kết quả:** root `flutter analyze` sạch, root `flutter test --exclude-tags slow` 1336/1336 pass (1 lần chạy giữa chừng gặp lại 2 flaky pre-existing khác nhau — `save_slot_manager_test.dart`/`season_event_service_test.dart` — máy tải nặng bất thường suốt phiên (suite chạy 90-135s thay vì ~50s bình thường), cả 2 pass khi chạy cô lập, không liên quan code). example `flutter analyze` sạch, `flutter test --exclude-tags slow` 56/56 pass. `dart run tool/api_compatibility.dart check` → unchanged (chỉ export trong `common_widgets.dart`). `dart pub publish --dry-run` → 1 warning (working-tree chưa commit).

Smoke device thật (Pixel 7 Pro, `2B051FDH3006MU`): build+cài `example` debug APK, mở Widget Kit, scroll tới section RetryErrorState — hiện đúng icon/title/message/nút Retry/diagnostic code "NETWORK-85F1E6D8". Bấm nút code → verify bằng `mobile_clipboard` (đọc thẳng clipboard hệ thống) thấy đúng `NETWORK-85F1E6D8` — copy hoạt động THẬT trên thiết bị, không chỉ giả lập trong test. Bấm Retry không crash. Không log lỗi (`level=Error` rỗng), `mobile_list_crashes` rỗng.

**Tự chấm điểm: 9/10** — compose từ 3 thành phần có sẵn (`EmptyStatePlaceholder`/`AsyncCommonButton`/`fnv1aHash`) thay vì tự dựng, an toàn message theo cấu trúc code (không theo quy ước phải nhớ), verify clipboard THẬT trên device (không chỉ mock trong test), bổ sung đủ 2 sprint-slice item ban đầu bỏ sót (`extraAction`, `liveRegion`) sau khi tự audit lại trước khi đóng task thay vì để sót. Trừ 1 điểm vì lần đầu implement bỏ sót 2 sprint-slice item đó — phải tự phát hiện qua rà soát lại thay vì làm đúng ngay từ đầu.
