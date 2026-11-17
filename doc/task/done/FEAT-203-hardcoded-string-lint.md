---
id: FEAT-203
title: "Lint chuỗi hard-code: Text('literal') trong widgets phải qua tham số hoặc .tr"
type: feature
layer: lib/core/utils/accessibility_audit + tool
priority: P3
effort: M
source: "ENH-105: 3 panel có chuỗi tiếng Anh không ghi đè được"
---

## Vấn đề
Consumer tiếng Việt thấy chuỗi tiếng Anh trong panel vì không có tham số override. Quy ước hiện tại chỉ nằm trong code mẫu.

## Phạm vi
- Rule mới: `Text('<chữ cái>...')`/`Semantics(label: '...')` có literal chứa chữ nhưng không đến từ tham số constructor hoặc `.tr`.
- Bỏ qua: file `debug_*`, `DebugQaOverlay`, `live_frame_graph` (dev-only), chuỗi chỉ ký hiệu/số/đơn vị.
- Mức `info` ở pha 1 để xem số lượng; chỉ nâng `warning` khi baseline gọn.

## Đã làm (2026-11-13): pha 1, rule mức info
`AuditRuleId.hardcodedString`: `Text('...')` và đối số `label:`/`title:`/`message:`/`hintText:`/`semanticLabel:`/`tooltip:` chứa chuỗi thường có >= 3 chữ cái, không nội suy `$`, bỏ qua định danh thường kiểu khoá dịch (`level_up_skip`), ký hiệu và comment. Trên repo: **23 file** bị báo, trong đó `debug_qa_overlay.dart` chiếm 44 chuỗi (dev-only, cần baseline). Mặc định audit vẫn xanh (mức info không chặn CI); CLI mặc định chỉ đếm các finding dưới ngưỡng và in "N lower-severity finding(s) not shown", `--minSeverity=info` để liệt kê. 2 test cho rule; test CLI cập nhật.
Việc còn lại: phân loại 23 file (mặc định tiếng Anh hợp lệ của tham số override, hay lỗi thật như `streak_shield_card` 'Current Streak'/'Freeze Shields' không ghi đè được), baseline `debug_qa_overlay`, rồi mới cân nhắc nâng lên warning.

## Đã làm (2026-11-14): pha 2, phân loại và sửa
Phân loại 23 file bị báo thành ba nhóm; audit mức info hiện **0 finding**:
- **Tham số override mặc định tiếng Anh giữ nguyên (không đổi hành vi)**, 20 chuỗi ở 20 widget: `EnergyBar.refillLabel`, `CandySearchBar.clearLabel`, `CommunityLeaderboardCard.refreshLabel` (validate không rỗng), `RetryErrorState.copiedLabel`/`copyHintLabel` (kể cả `fromSdkFailure`), `RewardChoicePanel.emptyMessage`/`claimedLabel`, `SaveSlotPicker` (`activeLabel`, `selectLabel`, `deleteTooltip`, `deleteTitle`, `deleteConfirmLabel`, `deleteCancelLabel`, `deleteMessageBuilder`), `PrestigeConfirmationCard` (`currentLabel`, `afterPrestigeLabel`, `rewardsHeader`), `StreakShieldCard` (`currentStreakLabel`, `shieldsLabel`), `AchievementRoadmapCard.claimLabel`, `RewardTrackRoad` (`claimLabel`, `claimedLabel`, đi qua `_TierColumn` và `_RewardCell`), `CharacterCollectionGrid` (`selectedBadgeLabel`, `selectedLabel`, `selectLabel`), `CollectionAlbumPanel.viewRewardLabel`, `GuildContributionCard.retryLabel`, `CraftingRecipeCard.materialsHeader`, `UpgradePreviewPanel.costHeader`, `VipPerkProgressRow.perksHeader`, `TeamRosterList.youLabel`, `RankPromotionDialog.rewardsHeader` (kể cả `show()`), `StarChestProgressHud.openLabel`, `ShimmerPlaceholder.semanticLabel`, `AppVersionGateOverlay.labels` (`AppVersionGateLabels`, gom 10 chuỗi, mặc định là các chuỗi Việt/Anh cũ).
- **Không phải chữ hiển thị, giữ nguyên + baseline có lý do**: `scene_transition_overlay` (message trong `SdkFailure` cho lập trình viên), `debug_qa_overlay` (dev-only).
- Test: `test/widget/common/feat203_label_overrides_test.dart` (19 test cho mọi override; không biên dịch được với `lib` cũ). `test/widget/common`, `test/core`, `test/tool`, `test/presentation` 3683 test, 442 test example, analyze và các cổng chất lượng đều xanh.
- API: không xoá gì; 23 chữ ký hàm dựng đổi (thêm tham số tên tuỳ chọn) nên snapshot được tạo lại, đã kiểm mọi mục "bị xoá" đều có bản mới cùng tên.
Còn lại: nâng rule lên mức warning khi muốn chặn chuỗi mới; chuỗi trong `DebugQaOverlay` và `SdkFailure` luôn nằm trong baseline.

## Tiêu chí xong
- Báo cáo danh sách baseline; mỗi mục hoặc có task thêm tham số override (mẫu ENH-105) hoặc nằm trong allowlist có lý do.

## Rủi ro
Nhiều false positive (tên riêng, ký hiệu); vì thế để ưu tiên thấp và `info` trước.
