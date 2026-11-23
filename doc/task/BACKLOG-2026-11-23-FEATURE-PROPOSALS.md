# Backlog 2026-11-23: đề xuất tính năng owner đã chọn

Nguồn: owner chọn từng đề xuất qua hỏi đáp ngày 2026-11-23. Mỗi task nằm ở `doc/task/todo/`. File này chỉ là chỉ mục: thứ tự gợi ý, phụ thuộc, cỡ việc. Chưa task nào được bắt đầu.

Định hướng owner: trọng tâm là SDK game + widget common + hàm/helper dùng chung; demo chỉ cần sơ sơ; chỉ hỗ trợ Android và iOS.

## Bảng task

| ID | Việc | Lớp | Cỡ | Ưu tiên |
|---|---|---|---|---|
| BUG-143 | `EnergyService.grantInfiniteLives` không validate duration | core | S | P3 |
| FEAT-232 | `fmtRelative` thời gian tương đối | core/utils | S | P3 |
| FEAT-216 | `UndoStack<T>` | core (+example tuỳ chọn) | S | P3 |
| FEAT-219 | Gacha/pity table | core | S | P3 |
| FEAT-215 | Grid + pathfinding BFS/A* | core | M | P3 |
| FEAT-220 | Replay player | core | M | P3 |
| FEAT-230 | Swipe 4 hướng (logic + widget bọc) | core + widget | M | P3 |
| FEAT-223 | `CandyBottomNavBar` | widget | M | P3 |
| FEAT-224 | `SettingsSection` + tile | widget | M | P3 |
| FEAT-226 | `OnboardingCarousel` | widget | M | P3 |
| FEAT-225 | `QuantityStepper` | widget | S | P4 |
| FEAT-227 | `CandyDropdown<T>` | widget | S | P4 |
| FEAT-228 | `StatBar` | widget | S | P4 |
| FEAT-231 | `PodiumWidget` | widget | M | P4 |
| FEAT-229 | `DialogueBox` | widget | M | P4 |
| FEAT-217 | FSM nhỏ | core | M | P4 |
| FEAT-221 | Wave/spawn scheduler | core | M | P4 |
| FEAT-233 | `playSfxVariant` | core | S | P4 |
| FEAT-222 | Thêm ngôn ngữ cho `AppTranslations` | core | M | P4 |
| FEAT-218 | Demo game thứ hai | example | M | P4 |

## Thứ tự gợi ý và lý do

1. **BUG-143** trước: sửa nhỏ, cùng họ lỗi đã đóng (ENH-116), không cần quyết định thiết kế ngoài việc duration <= 0 ném hay no-op.
2. **Đợt helper thuần Dart nhỏ** (FEAT-232, 216, 219): độc lập, không đụng UI hay golden, test host đủ.
3. **Đợt nền cho game** (FEAT-215, 220, 230): 215 và 230 là nền cho puzzle/lưới; 220 hoàn tất vòng ghi/phát replay.
4. **Đợt widget** (FEAT-223, 224, 226, rồi 225, 227, 228, 231, 229): mỗi widget cần golden Linux qua workflow `regenerate-goldens.yml`, nên gom commit widget + test trước, sinh baseline một lượt cho cả đợt để đỡ vòng chờ.
5. **Cuối**: FEAT-217, 221, 233, 222, 218 (giá trị thấp hơn hoặc có rủi ro đã ghi trong từng task).

## Phụ thuộc và xung đột cần nhớ

- **FEAT-224 và FEAT-227 cùng sửa `example/lib/screens/settings_screen.dart`** (settings tile, và thay `_pickLanguage` bằng `CandyDropdown`). Làm liền nhau hoặc cùng một người để khỏi xung đột; 227 nên sau 224.
- **FEAT-221 sau FEAT-215 và FEAT-217** (tránh thành engine trùng); **FEAT-218 sau 215/216/217**, và chỉ khi một trong số đó cần demo.
- **FEAT-232 và FEAT-222**: mỗi key dịch mới của `fmtRelative` phải có ở mọi locale được thêm sau.
- **FEAT-226** dùng `OnboardingCoordinatorService` (đã có), ranh giới với `tutorial_sequence` ghi trong task; **FEAT-229** bổ sung cho `tutorial_sequence`, không thay thế.
- **FEAT-217** phải giữ `GameSessionController` là nguồn sự thật phase phiên (ranh giới ghi trong task).
- **FEAT-233 phần đổi cao độ chưa kiểm chứng** (API `audioplayers` chưa đọc), chỉ phần chọn biến thể làm được ngay.
- Mọi task thêm export công khai cần `dart run tool/api_compatibility.dart snapshot`, CHANGELOG, và (task widget) golden qua workflow, không sinh trên macOS.

## Việc đã kiểm khi lập backlog (không phải giả định)

- Mỗi khẳng định "kit chưa có X" được kiểm bằng grep theo từng tên lớp trong `lib/`. Một lần sai đã được sửa: FEAT-227 ban đầu nói kit thiếu checkbox, nhưng `CandyCheckboxTile` đã có trong `candy_radio_group.dart`; chỉ còn thiếu dropdown. Task ghi rõ đính chính.
- Đề xuất `AnimatedNumberTicker` KHÔNG vào backlog: `CurrencyCounter` đã có số chạy (`duration`, `curve`, `enableTapToSkip`).
- Đã đo và thấy ổn (không tạo task): `DailyQuestService` đổi kỳ giữa phiên, `ExperimentBucketingService` phân phối và ổn định, `EnergyService` với `lastMs` xa tương lai/âm/count quá max, `PersistentCooldownService` với dữ liệu hỏng. Chi tiết trong BUG-143 và ENH-116.

## Chưa làm

- Chưa bắt đầu code task nào ở bảng trên.
- Chưa có ước lượng thời gian; cỡ S/M chỉ là phân loại tương đối.
