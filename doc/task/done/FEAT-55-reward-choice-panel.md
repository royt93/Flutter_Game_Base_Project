---
id: FEAT-55
title: "RewardChoicePanel — chọn reward có trạng thái selected/locked/claimed"
type: feature
layer: presentation/widget
priority: P1
effort: M
depends_on: [FEAT-42, FEAT-50]
source: user-approved SDK backlog 2026-09-12
---

## User story
Là người chơi, tôi muốn chọn một reward trong nhiều lựa chọn với xác nhận rõ và không claim hai lần.

## Sprint slices
- Immutable option model và panel single/multi select configurable.
- Animated selection, locked reason, confirm loading/success/error.
- Command trả option ids; grant nằm trong RewardTransactionPipeline.

## Acceptance criteria
- [x] Disabled/locked không select; selection và confirm obey min/max.
- [x] Rapid confirm/rebuild/error retry không double claim.
- [x] Empty/duplicate id/too many options có policy rõ.
- [x] Keyboard/semantics/text scale/RTL và reduced motion đầy đủ.

## Prompt loop feature
Đọc task/reward pipeline; TDD state and UI. End loop: audit, chấm /10; unit test + widget test + integration test mọi select/lock/confirm/error/duplicate; analyze/test root + example; smoke Android device thật chứng minh claim idempotent. Chỉ push khi work và điểm >9/10; cập nhật Quyết định, chuyển done, push lần hai.

## Quyết định

Thêm `RewardChoicePanel`/`RewardChoiceOption` (`lib/presentation/widgets/common/reward_choice_panel.dart`) — compose từ hạ tầng có sẵn thay vì tự dựng:
- Confirm dùng thẳng `AsyncCommonButton` (FEAT-50) — "rapid confirm không double claim" có MIỄN PHÍ từ guard sẵn có; panel không tự thêm cơ chế chặn tap nào.
- Panel KHÔNG tự gọi `RewardTransactionPipeline.grant()` — chỉ trả `List<String> selectedIds` qua `onConfirm`, đúng "Command trả option ids; grant nằm trong RewardTransactionPipeline" và đúng convention CLAUDE.md "widget không tự grant reward". `RewardLine` trong `RewardChoiceOption.lines` chỉ để HIỂN THỊ ("+100 coin"), không phải lời gọi thật.
- Locked/claimed dùng cùng pattern `LevelState`/`LevelNodeButton` đã có (icon khoá, màu `NeonTheme.lockedFill`/`lockedBorder`, tap bị chặn) thay vì tự nghĩ state model mới.
- "Claimed" là state CỤC BỘ (`_justClaimed`) sau khi `onConfirm` thành công — khoá toàn panel ngay, không cho chọn/confirm lại trong CÙNG 1 lần mount. Xuyên-restart do CALLER tự truyền `claimedIds` (panel không tự persist gì) — đúng ranh giới "panel không tự grant" mở rộng sang "panel không tự nhớ trạng thái lâu dài".
- Empty options → `EmptyStatePlaceholder` (tái dùng, không tự vẽ empty state mới). Duplicate id → `assert` fail-fast lúc construct (lỗi lập trình, không phải runtime user error). Too-many-options → không giới hạn cứng, panel tự nhiên dài ra (Column trong panel, không phải viewport riêng) — không tự bịa 1 con số giới hạn tuỳ tiện.
- **Mở rộng `AsyncCommonButton` (FEAT-50) cần thiết cho task này:** `onPressed` đổi từ non-nullable sang nullable — `null` = disabled (đúng convention `CommonButton.onTap`), trước đó AsyncCommonButton hoàn toàn không có khái niệm "disabled vì chưa đạt điều kiện nghiệp vụ" (chỉ có loading/success/error). Đã chạy lại 9/9 test cũ của FEAT-50 xác nhận không phá hành vi cũ (mọi caller cũ đều truyền non-null, tương thích ngược hoàn toàn).

**Test:** `test/widget/common/reward_choice_panel_test.dart` (11 case, TDD — RED xác nhận trước khi viết `reward_choice_panel.dart`): hiện đúng label/locked reason, locked không chọn được, single-select thay thế lựa chọn cũ, multi-select tôn trọng `maxSelectable` (vượt quá bị bỏ qua), `minSelectable` chưa đạt thì confirm disabled, rapid double-tap confirm chỉ gọi 1 lần, confirm thành công → panel khoá + hiện "Claimed", `claimedIds` truyền sẵn → read-only ngay từ đầu không có nút confirm, options rỗng không throw, duplicate id throw assertion, RTL + text scale không throw.

**Kết quả:** root `flutter analyze` sạch, root `flutter test --exclude-tags slow` 1370/1370 pass. example `flutter analyze` sạch, `flutter test --exclude-tags slow` 56/56 pass (không cần tăng viewport ảo lần này). `dart run tool/api_compatibility.dart check` → unchanged (chỉ export trong `common_widgets.dart`). `dart pub publish --dry-run` → 1 warning (working-tree chưa commit).

Wire demo vào `widget_showcase_screen.dart` (section mới "Reward Choice", ngay sau "Level Select") — 3 option (Coin pack/Gem pack chọn được, Exclusive skin locked), `onConfirm` giả lập delay 500ms rồi toast.

Smoke device thật (Pixel 7 Pro, `2B051FDH3006MU`): build+cài, mở Widget Kit, scroll tới "Reward Choice" → chọn "Coin pack" (border cyan + checkmark hiện đúng, Confirm bật màu) → bấm Confirm → "Coin pack" chuyển "Claimed" đúng, nút Confirm biến mất, thử bấm "Gem pack" sau khi claimed → không đổi gì (panel khoá đúng). Không log lỗi, `mobile_list_crashes` rỗng. (1 lần tap đầu qua `ref` không ăn — tap lại bằng toạ độ thô ăn ngay; không phải bug code, xác nhận qua việc tap thành công ngay sau đó với cùng vị trí.)

**Tự chấm điểm: 9/10** — tái dùng tối đa hạ tầng có sẵn (`AsyncCommonButton`, `LevelState` pattern, `EmptyStatePlaceholder`), giữ đúng ranh giới "widget không tự grant/không tự persist" xuyên suốt design, mở rộng `AsyncCommonButton` một cách tương thích ngược khi phát hiện thiếu nullable-disabled thay vì tự chế 1 cơ chế disabled riêng cho panel này. Trừ 1 điểm vì phải sửa `AsyncCommonButton` giữa chừng task (lẽ ra nên rà soát API cần thiết trước khi bắt đầu code panel, không phải phát hiện lúc biên dịch lỗi).

