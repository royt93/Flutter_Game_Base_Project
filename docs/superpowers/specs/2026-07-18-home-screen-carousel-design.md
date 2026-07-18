# Home Screen Carousel Redesign — design spec

**Ngày:** 2026-07-18 · **Task ID dự kiến:** X14 (supersede X9) · **Epic:** UX/retention

## Mục tiêu

User phản ánh trực tiếp: "màn hình menu hiện tại đơn điệu quá, user chê quá
nhiều, không đủ làm user hấp dẫn". X9 đã redesign Home Screen theo hướng
Drawer + 1 banner ưu tiên đơn (weekend > season ready > daily challenge >
ẩn) — vẫn tĩnh, chỉ hiện tối đa 1 thông báo tại 1 thời điểm, không phản ánh
tiến độ thực của người chơi. Redesign lần này kết hợp 4 hướng đã chốt qua
`AskUserQuestion` nhiều vòng: (1) carousel tiến độ thật (Star Road/Season
Pass/Achievements/Perks), (2) mascot sống động (tap reaction) + ambient
background nhẹ, (3) greeting cá nhân hoá + daily highlight, (4) Home đổi
theo mùa/sự kiện (weekend badge + accent color).

## Quyết định kiến trúc đã chốt

- **Thay thế hoàn toàn** `_buildPriorityBanner` trong `home_screen.dart`
  bằng 1 `HomeCarousel` (PageView) duy nhất — không giữ song song 2 khu vực
  thông báo.
- **Cách B** (đã chọn qua AskUserQuestion, dù không phải khuyến nghị ban
  đầu): thêm 1 GetX controller riêng `HomeScreenController` thay vì tính
  card trực tiếp trong widget — nhất quán với pattern `GameScreenController`
  đã có trong project.
- Hàm tính danh sách card (`buildHomeCards`) là **hàm thuần**, tách khỏi
  controller, để unit-test độc lập không cần dựng GetX/widget.

## 1. Data model — `lib/presentation/widgets/home_carousel.dart`

```dart
enum HomeCardType { greeting, starRoad, seasonPass, achievement, perk }

class HomeCardData {
  final HomeCardType type;
  final String Function(BuildContext) titleBuilder;
  final String Function(BuildContext) subtitleBuilder;
  final IconData icon;
  final Color accentColor;
  final String Function(BuildContext)? ctaLabelBuilder;
  final VoidCallback onTap;
  final String Function(BuildContext)? badgeTextBuilder;

  const HomeCardData({
    required this.type,
    required this.titleBuilder,
    required this.subtitleBuilder,
    required this.icon,
    required this.accentColor,
    this.ctaLabelBuilder,
    required this.onTap,
    this.badgeTextBuilder,
  });
}
```

Dùng `String Function(BuildContext)` thay vì `String` thô vì nội dung phụ
thuộc `.tr` (cần `BuildContext`/GetX locale) và số liệu động (X sao còn
thiếu, tên achievement) — build tại thời điểm render, không cache string.

## 2. `buildHomeCards(GameController gameCtrl)` — hàm thuần

Trả `List<HomeCardData>`, thứ tự cố định, mỗi loại chỉ xuất hiện nếu đáng
chú ý:

**Card Greeting (luôn có, index 0):**
- Text lời chào theo `DateTime.now().hour`: `< 11` → "buổi sáng", `11-17` →
  "buổi chiều", còn lại → "buổi tối".
- Subtitle ưu tiên: `gameCtrl.canClaimDaily` → CTA "Điểm danh nhận thưởng";
  else `gameCtrl.dailyStreak.value > 0` → "Đang giữ chuỗi N ngày"; else lời
  chào chung không có subtitle số liệu.
- Nếu `isWeekendEvent(DateTime.now())` đúng → set `badgeTextBuilder` →
  "🎉 Cuối tuần x2 xu!" và `accentColor` đổi sang tông vàng-tím
  (`NeonTheme.amber`/tương đương có sẵn) thay vì tông mặc định của card này
  — chỉ ảnh hưởng card Greeting, không ảnh hưởng theme toàn Home.
- `onTap`: mở Settings hoặc không làm gì nếu không có CTA cụ thể (card
  thuần thông tin) — nếu có CTA điểm danh, `onTap` gọi `gameCtrl.claimDaily()`.

**Card Star Road:** đáng chú ý nếu
`List.generate(GameController.starRoadMilestones.length, gameCtrl.canClaimChest).any((x) => x)`
đúng, HOẶC khoảng cách tới mốc `starRoadMilestones` gần nhất lớn hơn
`totalStars` là `≤ 3`. CTA "Nhận ngay" nếu có rương claimable (gọi
`claimChest(index)` tương ứng), ngược lại subtitle "Còn N sao nữa mở
rương kế tiếp". `onTap` mặc định điều hướng `StarRoadScreen`.

**Card Season Pass:** đáng chú ý nếu
`List.generate(GameController.seasonMilestones.length, gameCtrl.canClaimSeason).any((x) => x)`
đúng, HOẶC khoảng cách tới mốc `seasonMilestones` gần nhất lớn hơn
`seasonPoints.value` là `≤ 20`. CTA/subtitle tương tự Star Road. `onTap`
điều hướng `SeasonScreen`.

**Card Achievement:** đáng chú ý nếu `gameCtrl.justUnlockedAchievement.value
!= null` (card ăn mừng, ưu tiên cao nhất trong nhóm này — text "Vừa mở
khoá: <tên>!"), HOẶC tồn tại achievement trong `kAchievements` chưa nằm
trong `unlockedAchievementIds` có tỉ lệ
`gameCtrl.metricValue(a.metric) / a.threshold ≥ 0.8` (lấy achievement có
tỉ lệ cao nhất nếu nhiều ứng viên). `onTap` điều hướng `AchievementsScreen`.

**Card Perk:** đáng chú ý nếu
`gameCtrl.unlockedPerksList.length > gameCtrl.activePerkIds.value.length`
(có perk mở khoá nhưng chưa active — nhắc chọn kích hoạt), HOẶC
`worldsCompleted(gameCtrl.unlockedLevel.value)` cách world yêu cầu của perk
kế tiếp (perk đầu tiên trong `kPerks` chưa nằm trong
`unlockedPerks(gameCtrl.unlockedLevel.value)`) đúng 1 world. `onTap` điều
hướng `PerksScreen`.

**Không đáng chú ý ở cả 4 nhóm trên** → carousel chỉ có 1 card (Greeting) —
chấp nhận được, không cần fallback card giả để "lấp đầy".

## 3. `HomeScreenController` — `lib/presentation/controllers/home_screen_controller.dart`

```dart
class HomeScreenController extends GetxController with WidgetsBindingObserver {
  final RxList<HomeCardData> cards = <HomeCardData>[].obs;
  final RxInt currentIndex = 0.obs;

  void refreshCards(GameController gameCtrl) {
    cards.assignAll(buildHomeCards(gameCtrl));
    if (currentIndex.value >= cards.length) currentIndex.value = 0;
  }

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      refreshCards(Get.find<GameController>());
    }
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }
}
```

`HomeScreen.build` gọi `Get.put(HomeScreenController())` (idempotent — GetX
trả instance cũ nếu đã put) và `controller.refreshCards(gameCtrl)` trong
`initState`. Không `Get.delete` khi rời Home vì Home là root screen, sống
suốt vòng đời app — giữ instance để tránh mất `currentIndex` khi quay lại
(nhất quán với các singleton permanent khác, dù controller này không đăng
ký `permanent: true` trong `main.dart` — đăng ký tại chỗ dùng theo đúng
pattern `GameScreenController`).

## 4. `HomeCarousel` widget

`PageView.builder` bọc `Obx` đọc `controller.cards`/`controller.currentIndex`,
dot-indicator tự vẽ (`Row` các `AnimatedContainer` tròn nhỏ, không thêm
package). Mỗi card: `GestureDetector(onTap: card.onTap)` bọc 1 `Container`
bo góc theo `NeonTheme` token hiện có, icon + title + subtitle + CTA text
(nếu có) + badge góc trên (nếu có `badgeTextBuilder`).

## 5. Mascot tương tác + ambient background

- `star_mascot.dart`: thêm `onTap` optional param. Khi tap → chạy 1
  animation phản ứng ngẫu nhiên (chọn ngẫu nhiên giữa scale-bounce/tilt-
  wiggle) độc lập với idle loop hiện có, tôn trọng `_reduceMotion` (nếu bật,
  tap không chạy animation, chỉ đổi biểu cảm tĩnh nếu có, hoặc no-op).
- `lib/presentation/widgets/ambient_particles.dart` (mới): particle/ngôi
  sao trôi nhẹ, mật độ thấp (~5-8 particle), vẽ bằng `CustomPainter` đơn
  giản (không tái dùng trực tiếp confetti vì confetti là burst one-shot,
  ambient là loop liên tục nhẹ) — gate qua
  `StorageService.maybe?.getBool(StorageKeys.reduceMotion) ?? false`: nếu
  bật, `build()` trả `SizedBox.shrink()` ngay, không khởi tạo
  `AnimationController`.

## 6. i18n

Key mới cần thêm vào `AppTranslations` (đủ 22 locale, theo convention
`_extraEn`/`_extraVi` + wave 20 ngôn ngữ còn lại):
`home_greeting_morning`, `home_greeting_afternoon`, `home_greeting_evening`,
`home_daily_streak` (tham số N ngày), `home_weekend_badge`,
`home_star_road_claim`, `home_star_road_progress` (tham số N sao),
`home_season_claim`, `home_season_progress` (tham số N điểm),
`home_achievement_unlocked` (tham số tên), `home_achievement_progress`,
`home_perk_activate_reminder`, `home_perk_progress` (tham số N world).

## 7. Testing

- Unit test `buildHomeCards` (file mới `test/logic/home_cards_test.dart`
  hoặc tương đương thư mục test hiện có): cover đủ — chỉ greeting khi không
  gì đáng chú ý; mỗi nhánh đáng-chú-ý của 4 nhóm còn lại (claimable case và
  near-threshold case riêng); thứ tự cố định khi nhiều nhóm cùng đáng chú ý.
- Widget test tối thiểu cho `HomeCarousel`/`HomeScreenController` dùng đúng
  pattern GetX test setup + `StorageService.maybe` đã chuẩn hoá ở X13.
- Cập nhật `home_screen_test.dart`/`modes_test.dart` nếu đang assert theo
  `_buildPriorityBanner` cũ.

## Phạm vi KHÔNG làm (tránh scope creep)

- Không thêm asset hình ảnh mới cho theming mùa/sự kiện — chỉ dùng color
  token + text badge có sẵn.
- Không đổi `GameController` public API ngoài việc đọc field/hàm đã có sẵn
  (không thêm Rx/StorageKey mới ở tầng data — mọi tính toán "đáng chú ý"
  đều là derived, không cần persist).
- Không sort động thứ tự card theo độ ưu tiên tính toán — thứ tự cố định
  theo loại, đơn giản hoá để tránh logic sort phức tạp không cần thiết.
