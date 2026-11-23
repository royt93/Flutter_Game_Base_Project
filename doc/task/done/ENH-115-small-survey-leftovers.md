---
id: ENH-115
title: "Dọn vụn từ survey: overflow demo TooltipBubble, doc trần ví, registry thiếu hop, đồng hồ thô"
type: enhancement
layer: example + lib/core (doc)
priority: P3
effort: S
source: "Survey 2026-11-23 (chaos save, số/thời gian, widget trên Pixel 7 Pro)"
---

Gộp 4 mục nhỏ, không mục nào mất dữ liệu:

1. **Overflow demo showcase** (example, không phải widget của package): ở font scale 2.0 trên Pixel 7 Pro, `example/lib/screens/widget_showcase_screen.dart:2187` (demo `TooltipBubble`, `Row` chứa 2 bubble) tràn 11px bên phải (constraints w<=347.4). Cuộn hết showcase ở 2.0: đây là lỗi layout DUY NHẤT. Đề xuất: `Row` -> `Wrap`.
2. **Trần ví**: `EconomyWallet` giới hạn mỗi số dư ở `0x7fffffff` (2,147,483,647), từ chối vượt bằng `SdkFailure.validation`. Chưa nằm trong README/CHANGELOG. Game idle có số rất lớn cần biết. Chỉ ghi doc, không đổi hành vi.
3. **Registry thiếu hop**: `SaveMigrationRegistry` cho tạo khi chuỗi có khoảng trống (vd chỉ 1->2, `currentVersion: 3`); lỗi chỉ lộ khi `load()` (và save bị coi là không đọc được, xem BUG-141). Đề xuất validate liên tục lúc tạo (ném `SaveMigrationException`).
4. **Đồng hồ thô**: các `DateTime.now()` còn lại trong `lib/core` đều là dấu thời gian chẩn đoán/chứng từ (`createdAtMs`, `decidedAtMs`, `issuedAtMs`, analytics, diagnostics) hoặc bên trong `clamped_clock`/`trusted_clock`; không thấy chỗ nào bypass đồng hồ chống tua cho phần thưởng. Không cần sửa; ghi nhận.

## Chưa kiểm chứng (nói rõ)

- Landscape: app khoá portrait (`setPreferredOrientations(portraitUp)` trong `example/lib/main.dart`), nên không đo được landscape trên máy; chỉ có fixture `runViewportSweep` 568x320.
- RTL trên máy thật: chưa chạy (chỉ có golden `rtl` trên Linux).
- Season anchor ở tương lai, `PersistentCooldownService` với end-time xa tương lai: đọc code, chưa chứng minh bằng test.
- Font scale 2.0 chỉ cuộn một lượt qua showcase trên Pixel 7 Pro (không phải S24U theo quy tắc; owner đồng ý ngoại lệ ngày 2026-11-23).

## Kết quả thực hiện (2026-11-23)

- Mục 1: demo `TooltipBubble` `Row` -> `Wrap` (`widget_showcase_screen.dart`); chưa đo lại trên máy sau sửa (chỉ analyze + 472 test example).
- Mục 2: README (EconomyWallet) ghi trần 2,147,483,647 mỗi số dư.
- Mục 3: `SaveMigrationRegistry` ném `SaveMigrationException` lúc tạo nếu chuỗi hop có khoảng trống trước `currentVersion`. Test cũ "missing step" cập nhật (lỗi chuyển từ lúc `migrate` sang lúc tạo) + 2 case mới. CHANGELOG ghi Behavior change vì consumer tạo registry thiếu hop giờ ném sớm.
- Mục 4: chỉ ghi nhận, không sửa.

## Bổ sung đo trên máy thật (2026-11-23, Samsung SM_S928B / S24 Ultra)

Test tích hợp tạm (đã xoá) cuộn hết Widget Showcase (160 lần kéo) và đếm lỗi layout. Kết quả, đều 0 lỗi layout:

- RTL (`Get.updateLocale(ar)`, `Directionality` = rtl, 360x780dp).
- Landscape 780x360dp (ép bằng `setPreferredOrientations`, vì app khoá portrait).
- Landscape + font scale 2.0 (xác nhận `textScale` = 2.0 trong `MediaQuery`).

Mục 1 (overflow `TooltipBubble`) đã sửa nên sạch ở cả 3. Chưa đo: RTL + font 2.0 cùng lúc, các màn ngoài showcase, và "đẹp" bằng mắt (chỉ đếm tràn layout, không đo mirror icon sai hướng hay chạm 44dp). Season/cooldown với thời gian tương lai: đã đo (xem ENH-116).
