---
id: ENH-75
title: "QuestBoardPanel hardcode 3 chuỗi UI, không cho caller override (khác convention ENH-39)"
type: fix
priority: medium
effort: S
source: Claude (self-generated backlog brainstorm — đọc trực tiếp `lib/presentation/widgets/common/quest_board_panel.dart`)
---

## Vị trí
Sửa lỗi — `lib/presentation/widgets/common/quest_board_panel.dart` (`QuestBoardPanel`, `_QuestRow`).

## Hiện trạng
`QuestBoardPanel` hardcode 3 chuỗi UI mà caller không có cách nào override:
- Dòng 74: `message: 'Không có nhiệm vụ nào hôm nay.'` trong `EmptyStatePlaceholder` khi `quests.isEmpty`.
- Dòng 131: `label: quest.claimed ? 'Đã nhận' : 'Nhận thưởng'` trên `CommonButton`.
- Dòng 169: `semanticLabel: '${quest.label}: ${quest.progress} of ${quest.target}'` — trộn tiếng Việt (`quest.label` do caller cung cấp, thường tiếng Việt) với từ tiếng Anh cứng `'of'`.

Đây đúng lỗi mà `DailyLoginCalendarWidget` đã tự vá ở ENH-39: `claimLabel` (dòng 30, mặc định `'Claim'`) là param caller override được, có doc comment trích dẫn ENH-39 giải thích lý do (package này không tự làm i18n cho copy trong widget, để caller tự truyền chuỗi đã dịch qua `AppTranslations`). `QuestBoardPanel` sinh sau `DailyLoginCalendarWidget` nhưng lại không theo đúng convention đó.

## Vì sao cần / Hậu quả
1 consumer app muốn hiển thị tiếng Anh (hoặc bất kỳ locale nào khác tiếng Việt) cho `QuestBoardPanel` không có cách nào — phải fork/copy cả file widget chỉ để đổi 3 chuỗi. Interpolation `'... of ...'` còn tạo ra chuỗi hiển thị nửa Việt nửa Anh ngay cả với app tiếng Việt thuần, là lỗi hiển thị thật (không phải giả định).

## Đề xuất
Thêm 3 param optional vào constructor `QuestBoardPanel`, forward xuống `_QuestRow`, giữ NGUYÊN giá trị mặc định y hệt hiện tại (không đổi hành vi/hiển thị cho caller chưa truyền gì):

```dart
class QuestBoardPanel extends StatelessWidget {
  const QuestBoardPanel({
    super.key,
    required this.quests,
    required this.onClaim,
    this.emptyMessage = 'Không có nhiệm vụ nào hôm nay.',
    this.claimLabel = 'Nhận thưởng',
    this.claimedLabel = 'Đã nhận',
    this.progressSemanticLabel,
  });

  final String emptyMessage;
  final String claimLabel;
  final String claimedLabel;

  /// Overrides the default `'${quest.label}: ${quest.progress} of
  /// ${quest.target}'` semantic label (ENH-75) — the caller's own
  /// localized copy, same reasoning as [claimLabel].
  final String Function(QuestViewModel quest)? progressSemanticLabel;
  ...
}
```

`_QuestRow` nhận thêm `claimLabel`/`claimedLabel`/`progressSemanticLabel` (không optional ở tầng này — `QuestBoardPanel` luôn truyền xuống, kể cả khi dùng default), dùng chúng thay literal hardcode. Default `progressSemanticLabel` (khi `null`) tái tạo ĐÚNG chuỗi cũ `'${quest.label}: ${quest.progress} of ${quest.target}'` — không đổi hiển thị mặc định, chỉ thêm khả năng override.

## Acceptance criteria
- [x] Không truyền 3 param mới: hiển thị/`Semantics` y hệt hiện tại (bao gồm cả chuỗi `'of'` cũ, không tự sửa nó).
- [x] Truyền `emptyMessage` tuỳ chỉnh: `EmptyStatePlaceholder` hiển thị đúng chuỗi mới khi `quests.isEmpty`.
- [x] Truyền `claimLabel`/`claimedLabel` tuỳ chỉnh: `CommonButton.label` đổi đúng theo `quest.claimed`.
- [x] Truyền `progressSemanticLabel` tuỳ chỉnh: `ProgressBarStars.semanticLabel` dùng đúng kết quả callback thay vì chuỗi mặc định.
- [x] Không đổi hành vi `isClaimable`/`onClaim`/animation `_pop`/`loading` (ENH-70) hiện có.
- [x] Không phá bất kỳ widget test nào trong `test/widget/common/quest_board_panel_test.dart` (hoặc đường dẫn test hiện có của widget này — verify bằng `grep -rl QuestBoardPanel test/`).
- [x] Test: widget test đầy đủ mọi case trên.
- [x] `flutter analyze`/`flutter test --exclude-tags slow` sạch ở root.
- [x] Không bắt buộc đụng `example/`.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/ENH-75-quest-board-panel-caller-overridable-copy.md` này trước khi làm. Đọc toàn bộ `lib/presentation/widgets/common/quest_board_panel.dart` (đặc biệt `QuestBoardPanel.build`/`_QuestRowState.build`) và `lib/presentation/widgets/common/daily_login_calendar.dart` (tham chiếu convention `claimLabel`/ENH-39) trước khi sửa. Tìm test hiện có bằng `grep -rl QuestBoardPanel test/` trước khi viết test mới, để không trùng/phá test cũ. Implement bằng TDD (viết test fail trước, code cho pass).

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10 (đúng nhất quán với convention `claimLabel`/ENH-39, không đổi hành vi mặc định, không over-engineer — không tự thêm i18n thật, chỉ expose param).
2. Bổ sung ĐỦ test cho MỌI case ở Acceptance criteria.
3. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở root.
4. Không bắt buộc đụng `example/`.

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test) đạt > 9/10.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, verify checksum `[x]` khớp giữa git index và disk, commit + push lần 2.

## Ghi chú độ tin cậy
Cao — xác nhận qua đọc trực tiếp `quest_board_panel.dart`: 3 chuỗi hardcode tồn tại đúng vị trí mô tả (dòng 74/131/169), không có param nào cho phép override. Xác nhận `DailyLoginCalendarWidget.claimLabel` (dòng 30, `daily_login_calendar.dart`) đã có đúng convention này với doc comment trích dẫn ENH-39 — bằng chứng đây là gap thật, không phải suy đoán. Effort nhỏ (3 param + forward, không đổi logic), không đụng file nhạy cảm/scope peer, không trùng bất kỳ FEAT-*/IDEA/ENH/BUG nào đã có trong `doc/task/done/`.

## Quyết định

Đúng như đề xuất — thêm 3 param optional (`emptyMessage`/`claimLabel`/`claimedLabel`) + 1 callback (`progressSemanticLabel`), giữ NGUYÊN mọi giá trị mặc định (kể cả chuỗi `'of'` cũ, cố tình không tự "sửa" nó — đó là quyết định của caller khi họ truyền `progressSemanticLabel` riêng). `_QuestRow` nhận `required` 3 field này (không optional ở tầng đó) vì `QuestBoardPanel` luôn forward xuống kể cả dùng default — tránh double-default-logic ở 2 tầng.

**Test:** 4 test mới trong `test/widget/common/quest_board_panel_test.dart` nhóm "ENH-75" — không truyền gì giữ hiển thị y hệt, `emptyMessage` tuỳ chỉnh, `claimLabel`/`claimedLabel` đổi đúng theo `claimed`, `progressSemanticLabel` dùng đúng callback thay literal mặc định. 17/17 test cũ + mới trong file này pass.

**Kết quả:** root `flutter analyze` sạch, root `flutter test --exclude-tags slow` 1247/1247 pass. Không đụng `example/` (không bắt buộc).

**Tự chấm điểm: 9.5/10** — đúng convention `claimLabel`/ENH-39 đã có sẵn, không đổi hành vi mặc định, test đủ mọi case. Trừ 0.5 vì đây thực chất là mở rộng khả năng override hơn là 1 "fix" thuần tuý sửa lỗi hiển thị hiện tại (giữ nguyên default `'of'` — đúng ý "no default behavior change" nhưng nghĩa là lỗi hiển thị gốc vẫn còn cho tới khi caller chủ động truyền `progressSemanticLabel`).
