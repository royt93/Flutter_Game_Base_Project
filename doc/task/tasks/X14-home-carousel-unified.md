# X14 — Home Screen Carousel Redesign: carousel động thay banner ưu tiên đơn

**Supersedes:** `X9-home-screen-redesign.md` (banner ưu tiên đơn — chỉ hiện
được 1 thứ tại một thời điểm).

## Mục tiêu

Banner ưu tiên đơn của X9 (weekend event > Season Pass > Daily Challenge,
theo thứ tự ưu tiên cố định, chỉ 1 banner hiện tại một thời điểm) che khuất
mọi tín hiệu khác: user có thể có cả rương Star Road sẵn sàng nhận **và**
achievement vừa mở khoá cùng lúc, nhưng chỉ thấy được 1 trong 2. Thay bằng
**carousel `PageView`** hiện đồng thời mọi thẻ đang "đáng chú ý" tại thời
điểm mở Home, theo spec đã duyệt trước
(`docs/superpowers/specs/2026-07-18-home-screen-carousel-design.md`).

## Vì sao

Spec đã được duyệt trước khi implement (không cần hỏi lại lựa chọn thiết
kế). 5 loại thẻ theo đúng thứ tự cố định trong spec: greeting (luôn có) →
Star Road → Season Pass → achievement → perk. Mascot (`StarMascot`) và nền
hạt trôi (`AmbientParticles`) được thêm cùng đợt để Home Screen sống động
hơn nhưng vẫn tôn trọng "Giảm chuyển động" đã có từ X13.

## Đã sửa

- **`buildHomeCards(GameController)`** (`lib/presentation/widgets/
  home_carousel.dart`) — hàm thuần (không phụ thuộc `BuildContext`/GetX
  ngoài đọc state), test độc lập được, sinh `List<HomeCardData>` theo thứ
  tự cố định. Điều kiện "đáng chú ý" từng loại:
  - **Star Road**: `canClaimChest` (có rương khả nhận) HOẶC còn ≤3 sao tới
    mốc kế tiếp trong `starRoadMilestones`.
  - **Season Pass**: `canClaimSeason` HOẶC còn ≤20 điểm tới mốc kế tiếp
    trong `seasonMilestones`.
  - **Achievement**: `justUnlockedAchievement` vừa set (Rxn) HOẶC đạt ≥80%
    ngưỡng của achievement tiếp theo chưa unlock.
  - **Perk**: có perk đã unlock (`unlockedPerksList`) nhưng chưa active
    (`activePerkIds`) HOẶC perk kế tiếp (`kPerks` theo `unlockAfterWorld`)
    chỉ còn cách đúng 1 world (`worldsCompleted(unlockedLevel.value)`).
- **`HomeCarousel`** widget — `PageView.builder` (`viewportFraction: 0.92`)
  + dot-indicator (`AnimatedContainer` theo `currentIndex`), mỗi card viền
  `accentColor` riêng theo loại, badge góc trên tuỳ chọn (`badgeTextBuilder`
  — vd. weekend event "🎉 Weekend x2 coins!").
- **`HomeScreenController`** (`lib/presentation/controllers/
  home_screen_controller.dart`) — `GetxController with
  WidgetsBindingObserver`; `cards` (`RxList<HomeCardData>`), `currentIndex`
  (`RxInt`); `refreshCards(GameController)` gọi lại `buildHomeCards` và kẹp
  `currentIndex` về 0 nếu vượt số thẻ mới; `didChangeAppLifecycleState`
  refresh khi app resume (thẻ có thể đổi trong lúc app ở background, vd.
  qua nửa đêm đổi greeting).
- **`AmbientParticles`** (`lib/presentation/widgets/ambient_particles.dart`)
  — 7 hạt trôi nhẹ phía sau mascot; tôn trọng "Giảm chuyển động": nếu bật
  cờ, `build()` trả `SizedBox.shrink()` **trước khi** tạo
  `AnimationController` (không tốn ticker).
- **`StarMascot`** — thêm param `onTap` (optional). Tap gọi callback rồi
  (nếu không reduce-motion) chạy 1 trong 2 animation phản ứng ngẫu nhiên
  (scale-bounce/tilt-wiggle, 500ms) độc lập với idle-bob loop sẵn có.
- 12 key i18n mới (`home_greeting_morning/afternoon/evening`,
  `home_daily_streak`, `home_weekend_badge`, `home_star_road_claim`,
  `home_star_road_progress`, `home_season_claim`, `home_season_progress`,
  `home_achievement_unlocked`, `home_achievement_progress`,
  `home_perk_activate_reminder`, `home_perk_progress`) trong
  `AppTranslations`, đủ 22 locale. Không thêm `StorageKeys` mới — carousel
  chỉ đọc lại state Rx đã có sẵn trên `GameController`.
- `home_screen.dart`: xoá `_buildPriorityBanner`/`_bannerContainer` (X9),
  gọi `Get.put(HomeScreenController()).refreshCards(gameCtrl)` trong
  `initState`, render `HomeCarousel` bọc `Obx` thay cho banner cũ; thêm
  `AmbientParticles` + `StarMascot(onTap: ...)` trong `Stack`.

**Regression tự phát hiện + tự sửa trong cùng phiên:** thêm `_tapC`
(`AnimationController` thứ 2, cho phản ứng tap) vào `_StarMascotState`
trong khi class vẫn khai `with SingleTickerProviderStateMixin` (chỉ hỗ trợ
đúng 1 ticker) → crash runtime "A SingleTickerProviderStateMixin can only
be used as a TickerProvider once", lan ra **31 test fail** ở nhiều file
không liên quan tới X14 (mọi test render `StarMascot`: `swap_freeze_test`,
`boot_resilience_test`, `modes_test`, `game_screen_smoke_test`,
`colorblind_mode_test`, `level_path_map_test`, `free_undo_test`,
`home_screen_test`, `objective_test`, `power_tile_*_test`, golden tests...).
Fix root-cause 1 dòng tại định nghĩa class (không vá từng file test gọi
đến): `with SingleTickerProviderStateMixin` → `with
TickerProviderStateMixin`.

## Acceptance criteria

- [x] `flutter analyze` → 0 issues.
- [x] `flutter test --exclude-tags slow` → 272 test xanh toàn bộ (thêm mới
      `test/presentation/home_carousel_test.dart`, 11 test cho
      `buildHomeCards`: thứ tự cố định, từng điều kiện "đáng chú ý" riêng
      lẻ, và nhiều nhóm đáng chú ý cùng lúc).
- [x] Build + chạy debug trên Android emulator (`emulator-5554`, Android 17
      / API 37 — thiết bị Android duy nhất kết nối):
  - [x] Carousel hiện đúng state thật: greeting card + badge "Weekend x2
        coins!" (test đúng ngày 2026-07-18 = thứ Bảy) + dot-indicator ứng
        với 2 thẻ đáng chú ý (greeting + perk, vì fresh install world kế
        tiếp luôn cách đúng 1 world).
  - [x] Vuốt carousel chuyển mượt sang thẻ Perks ("1 more world to unlock
        a new perk", viền hồng) — xác nhận card thật, không phải placeholder.
  - [x] Tap mascot không crash (đã tự phát hiện + sửa regression
        multi-ticker ở trên trước khi verify tay).
  - [x] Tap thẻ Perks điều hướng đúng sang `PerksScreen` (hiện đúng 3 perk
        khoá: Extra Undo/Quick Hint/Coin Bonus).
  - [x] Không gặp quảng cáo che UI ở bất kỳ bước nào trong toàn bộ phiên
        verify tay.

## Ghi chú

- `_perkCard` luôn "đáng chú ý" ở trạng thái mới toanh (`unlockedLevel=1`)
  vì world kế tiếp của perk đầu tiên (`unlockAfterWorld: 1`) luôn cách
  đúng 1 world khi `worldsCompleted(1) = 0`. Test `home_carousel_test.dart`
  dùng baseline `neutralize()` (đẩy `unlockedLevel = 61`, qua hết world có
  perk liên quan + active hết perk đã unlock) làm điểm "không có gì đáng
  chú ý", rồi mỗi test chỉ bật đúng 1 điều kiện trên nền đó.
- Không đổi cách "Giảm chuyển động" hoạt động ở các widget X13 cũ
  (`confetti_overlay`, `pulse_glow`, `coin_fly_overlay`,
  `level_select_screen`) — `AmbientParticles`/`StarMascot.onTap` chỉ tái
  dùng đúng pattern `StorageService.maybe?.getBool(StorageKeys
  .reduceMotion) ?? false` đã có sẵn.
- Không thử lại việc mở Settings để bật/tắt "Giảm chuyển động" bằng tay
  qua nhiều lần tap drawer bị trượt (không phải bug — do ước lượng toạ độ
  tap trên ảnh chụp màn hình chưa chính xác); logic gating đã được xác
  nhận đúng qua code + qua test tự động, không lặp lại thao tác tay chỉ vì
  toạ độ tap khó trúng.

DoD chung: `../README.md`.
