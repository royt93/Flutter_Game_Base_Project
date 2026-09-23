---
id: FEAT-95
title: "PrestigeService — cơ chế trùng sinh/thăng hoa (soft-reset đổi lấy meta-currency vĩnh viễn) kinh điển của idle game"
type: feature
priority: P1
effort: M
source: "agy (độc lập)"
---

## Vị trí
Mới `lib/core/prestige_service.dart` — dựa trên `lib/core/economy_wallet.dart`, `lib/core/offline_progression_service.dart`, `lib/core/utils/economy_math.dart`.

## Hiện trạng
Kit đã có `OfflineProgressionService` và `EconomyWallet` nhưng thiếu hoàn toàn engine quản lý vòng đời "Prestige" — cơ chế cốt lõi của mọi tựa game Idle/Incremental (Cookie Clicker, Adventure Capitalist): người chơi tích luỹ tài nguyên đến ngưỡng, kích hoạt soft-reset các tài nguyên cấp thấp, quy đổi sang meta-currency vĩnh viễn với hệ số nhân tăng dần.

## Vì sao cần / Hậu quả
Đây là gap thể loại rõ ràng nhất cho 1 "casual/idle-game SDK" — thiếu cơ chế này khiến kit chưa thật sự đủ cho genre idle/incremental dù đã có phần lớn hạ tầng kinh tế cần thiết.

## Đề xuất
Thêm `PrestigeService`: `canPrestige()` (đủ ngưỡng tài nguyên), `prestige()` (soft-reset tài nguyên cấp thấp qua `EconomyWallet`, cộng meta-currency theo công thức `multiplier = 1 + (relics * bonusPerRelic)` — hàm thuần trong `economy_math.dart` để `tool/economy_sim.dart` cross-check được), `currentMultiplier` (hệ số nhân đang áp dụng cho earn rate).

## Acceptance criteria
- [x] `PrestigeService.canPrestige()` đúng theo ngưỡng cấu hình.
- [x] `prestige()` soft-reset đúng tài nguyên cấp thấp, cộng đúng meta-currency, không mất/nhân đôi dữ liệu.
- [x] `currentMultiplier` áp dụng đúng vào rate tính toán của `OfflineProgressionService`/`EnergyService` (nếu tích hợp) sau khi prestige.
- [x] Công thức tính multiplier là hàm thuần trong `lib/core/utils/economy_math.dart`, có cross-check trong `tool/economy_sim.dart`/`test/tool/economy_sim_test.dart` (đúng convention hiện có).
- [x] Test unit đầy đủ, demo trong `example/`.

## Prompt (dùng cho /loop hoặc giao cho agent độc lập)
Đọc kỹ file `doc/task/todo/FEAT-95-idle-prestige-ascension-engine.md` này trước khi làm. Đọc toàn bộ `lib/core/economy_wallet.dart`, `lib/core/offline_progression_service.dart`, `lib/core/utils/economy_math.dart`, `tool/economy_sim.dart` (convention hàm thuần dùng chung giữa service thật và simulator) trước khi implement. Implement bằng TDD.

Vòng lặp CHỈ được coi là xong khi TẤT CẢ các điều sau đạt:
1. Tự audit lại code changes vừa viết, chấm điểm /10.
2. Bổ sung ĐỦ unit test cho MỌI case ở Acceptance criteria, kể cả cross-check `tool/economy_sim.dart`.
3. Chạy `flutter analyze` + `flutter test --exclude-tags slow` sạch ở root VÀ ở `example/`, `dart run tool/api_compatibility.dart check` pass.
4. Smoke test trên device thật khuyến khích (demo prestige trong example, verify UI/số liệu đúng) không bắt buộc nếu unit/widget test đủ chứng minh.

Chỉ `git commit` + `git push` khi điểm tự chấm ở bước 1 (SAU KHI đã có đủ test) đạt > 9/10.

Sau khi push, viết mục `## Quyết định` vào chính file task này (tick các checkbox Acceptance criteria đã đạt `[x]`), rồi chuyển file từ `doc/task/todo/` sang `doc/task/done/` bằng `git mv`, verify checksum `[x]` khớp giữa git index và disk, commit + push lần 2.

## Ghi chú độ tin cậy
Cao — gap thể loại rõ ràng, hợp lý cho định hướng "casual/idle-game SDK" của kit; dựa trên hạ tầng kinh tế đã có thật (`EconomyWallet`, `economy_math.dart`). Không trùng task nào trong `doc/task/done/`.

## Quyết định
**Đã làm, đạt 9.5/10, đã commit + push.**

**Implement**:
- `lib/core/utils/economy_math.dart` — `prestigeMultiplier({relics, bonusPerRelic}) = 1 + relics * bonusPerRelic` (hàm thuần, validate input fail-loud cùng convention `regenEnergy`/`offlineEarnings`).
- `lib/core/prestige_service.dart` — `PrestigeService(wallet, primaryCurrency, metaCurrency, prestigeThreshold, bonusPerRelic, relicsPerPrestige, softResetCurrencies)`:
  - `canPrestige()` — so `wallet.balanceOf(primaryCurrency) >= prestigeThreshold`.
  - `currentMultiplier` — đọc trực tiếp `wallet.balanceOf(metaCurrency)` qua `prestigeMultiplier`, không tự lưu trạng thái riêng.
  - `prestige()` — soft-reset TỪNG currency trong `softResetCurrencies` (mỗi cái 1 giao dịch `trySpend` riêng, transactionId tự sinh unique qua counter nội bộ — tự bắt được kịch bản "không mất/nhân đôi dữ liệu" dù gọi `prestige()` nhiều lần), rồi `earn` đúng `relicsPerPrestige` vào `metaCurrency`. `assert` cấu trúc: `metaCurrency` không được nằm trong `softResetCurrencies` (bảo vệ khỏi tự cấu hình sai làm mất chính relic vừa cộng).
  - 100% xây trên `EconomyWallet` sẵn có — KHÔNG có storage riêng, không format persist mới cần đồng bộ.

**Quyết định thiết kế quan trọng**: `currentMultiplier` KHÔNG được tự động tích hợp vào `OfflineProgressionService`/`EnergyService` bên trong `PrestigeService` — cả 2 service đó nhận `rate`/`interval` từ CALLER (không tự suy ra), nên tích hợp đúng nghĩa (theo đúng "(nếu tích hợp)" trong acceptance criteria) là caller tự nhân `currentMultiplier` vào rate của mình trước khi gọi — demo trong `example/` chứng minh đúng luồng này (`offline.claim(0.5 * prestige.currentMultiplier)`), không cần sửa/thêm coupling vào 2 service cốt lõi kia.

**`tool/economy_sim.dart` cross-check**: `EconomyScenario` thêm `relics`/`bonusPerRelic` (default `0`/`0` — không breaking scenario cũ, tương đương `prestigeMultiplier(relics: 0, ...) == 1`). `simulateEconomy` nhân `prestigeMultiplier(...)` vào `productionRatePerSecond` TRƯỚC vòng lặp session (tính 1 lần, không phải input đổi theo session) — cùng công thức `PrestigeService.currentMultiplier` gọi, từ cùng file `economy_math.dart`. Thêm 2 flag CLI `--relics`/`--bonusPerRelic` khớp convention hiện có.

**TDD**: 6 test `prestigeMultiplier` trong `economy_math_test.dart` (0 relic→1; đúng công thức; bonusPerRelic=0→luôn 1; relics âm/bonusPerRelic âm/NaN/Infinity→throw). 12 test `prestige_service_test.dart` (canPrestige dưới/bằng/trên ngưỡng; currentMultiplier đúng công thức; prestige dưới ngưỡng→SdkFailure không đổi gì; đủ ngưỡng→soft-reset đúng+cộng đúng relic+SdkSuccess; 2 lần liên tiếp→relic cộng dồn không ghi đè; không trùng transactionId qua nhiều lần gọi; softResetCurrencies tuỳ chỉnh chỉ ảnh hưởng đúng currency; currency soft-reset đã sẵn 0 không throw; assert cấu hình sai). 2 test cross-check mới `economy_sim_test.dart` (relics=0 mặc định giống hệt không truyền gì; relics/bonusPerRelic scale cumulativeCurrency ĐÚNG hệ số so với scenario tương đương, energy curve không đổi). Xác nhận fail đúng lỗi biên dịch khi tạm xoá/`git stash` từng file lib liên quan, khôi phục toàn bộ pass (6+12+2/20 test mới, cộng 8 test `economy_sim_test.dart` cũ vẫn pass nguyên).

**Demo `example/`**: `CookbookScreen`'s "Economy & progression" — 1 tile "PrestigeService — accumulate + prestige + apply multiplier" (earn đủ coins → prestige → nhân multiplier vào `OfflineProgressionService.claim()` thật, hiện relics/multiplier/earned). Reuse `EconomyWallet`/`OfflineProgressionService` instance thật (cùng `.maybe ?? Get.put` convention đã dùng khắp file này). 1 widget test mới trong `cookbook_screen_more_test.dart`.

**Kết quả**: `flutter analyze` sạch ở root và `example/`. `flutter test --exclude-tags slow` root: 2209 test, 19 fail — khớp đúng baseline golden-image macOS-only đã biết. `example/`: 140/140 pass. `dart run tool/api_compatibility.dart check`: `additive` (thêm `PrestigeService`) → `snapshot` → `unchanged`.

**Không làm** (khuyến khích, không bắt buộc theo task): smoke test device thật — unit/widget test đã đủ chứng minh toàn bộ luồng (bao gồm tích hợp multiplier vào rate thật).
