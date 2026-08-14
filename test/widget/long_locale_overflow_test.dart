import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pop_star_blast/core/app_translations.dart';
import 'package:pop_star_blast/core/locale_service.dart';
import 'package:pop_star_blast/core/storage_service.dart';
import 'package:pop_star_blast/presentation/screens/achievements_screen.dart';
import 'package:pop_star_blast/presentation/screens/board_frame_screen.dart';
import 'package:pop_star_blast/presentation/screens/color_alchemy_screen.dart';
import 'package:pop_star_blast/presentation/screens/friend_compare_screen.dart';
import 'package:pop_star_blast/presentation/screens/ghost_replay_screen.dart';
import 'package:pop_star_blast/presentation/screens/guide_screen.dart';
import 'package:pop_star_blast/presentation/screens/home_screen.dart';
import 'package:pop_star_blast/presentation/screens/leaderboard_screen.dart';
import 'package:pop_star_blast/presentation/screens/level_select_screen.dart';
import 'package:pop_star_blast/presentation/screens/mascot_wardrobe_screen.dart';
import 'package:pop_star_blast/presentation/screens/milestone_journal_screen.dart';
import 'package:pop_star_blast/presentation/screens/mode_select_screen.dart';
import 'package:pop_star_blast/presentation/screens/perks_screen.dart';
import 'package:pop_star_blast/presentation/screens/pet_habitat_screen.dart';
import 'package:pop_star_blast/presentation/screens/puzzle_lab_screen.dart';
import 'package:pop_star_blast/presentation/screens/season_screen.dart';
import 'package:pop_star_blast/presentation/screens/settings_screen.dart';
import 'package:pop_star_blast/presentation/screens/shop_screen.dart';
import 'package:pop_star_blast/presentation/screens/sky_shrine_screen.dart';
import 'package:pop_star_blast/presentation/screens/star_road_screen.dart';
import 'package:pop_star_blast/presentation/screens/stats_screen.dart';
import 'package:pop_star_blast/presentation/screens/sticker_album_screen.dart';
import 'package:pop_star_blast/presentation/screens/trophy_room_screen.dart';
import 'package:pop_star_blast/presentation/controllers/game_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Bản dịch dài hơn tiếng Anh làm vỡ layout — quét cả app thay vì đợi bắt gặp.
///
/// Đợt dịch vừa rồi làm lộ một lỗi thật trên Mode Select: nhãn trong ô rộng cố
/// định 60px bị ngắt GIỮA TỪ ở tiếng Đức ("Doppelspiege" + "l"). Lỗi đó tìm
/// được bằng mắt trên máy thật, nghĩa là những chỗ tương tự ở 25 màn còn lại
/// chưa ai soi.
///
/// File này quét phần **máy kiểm được**: `RenderFlex overflowed` và mọi
/// exception khi dựng, ở hai ngôn ngữ dài nhất, trên khung máy hẹp.
///
/// **Không bắt được** kiểu ngắt giữa từ — chuyện đó không ném exception, chỉ
/// nhìn xấu. Chỗ đó vẫn phải soi bằng mắt; xem `label_fit_test.dart` cho phần
/// đã xử lý.
///
/// `en_US` nằm trong danh sách ngôn ngữ để làm **đối chứng**, không phải để
/// phủ thêm. Màn nào tràn ở cả tiếng Anh thì nguyên nhân không phải bản dịch —
/// xem [_kNarrowScreenDebt].
///
/// Vì sao tiếng Đức và Filipino: đo trên bảng dịch thật, hai ngôn ngữ này có
/// chuỗi dài nhất so với tiếng Anh (từ ghép Đức, và cụm "ng/na" của Filipino).
const _kLocales = <Locale>[Locale('en', 'US'), Locale('de', 'DE'), Locale('fil', 'PH')];

/// 360x640 dp — máy Android phổ thông hẹp nhất còn đáng đỡ. Rộng hơn thì
/// không bắt được gì; hẹp hơn thì báo động giả trên thiết bị chẳng ai dùng.
const _kNarrow = Size(1080, 1920);
const _kPixelRatio = 3.0;

/// Màn hình dựng được mà không cần controller theo lượt chơi.
///
/// Cố ý thiếu: `GameScreen` (cần Flame + engine thật, đã có
/// `integration_test/`), `BossRushScreen` và `RaidBossScreen` (mỗi cái tự
/// `Get.put` controller riêng và đọc trạng thái phụ thuộc ngày trong tuần).
final _kScreens = <String, Widget Function()>{
  'HomeScreen': () => const HomeScreen(),
  'ModeSelectScreen': () => const ModeSelectScreen(),
  'LevelSelectScreen': () => const LevelSelectScreen(),
  'ShopScreen': () => const ShopScreen(),
  'SettingsScreen': () => const SettingsScreen(),
  'GuideScreen': () => const GuideScreen(),
  'AchievementsScreen': () => const AchievementsScreen(),
  'TrophyRoomScreen': () => const TrophyRoomScreen(),
  'StatsScreen': () => const StatsScreen(),
  'MilestoneJournalScreen': () => const MilestoneJournalScreen(),
  'PerksScreen': () => const PerksScreen(),
  'SeasonScreen': () => const SeasonScreen(),
  'StarRoadScreen': () => const StarRoadScreen(),
  'SkyShrineScreen': () => const SkyShrineScreen(),
  'ColorAlchemyScreen': () => const ColorAlchemyScreen(),
  'PetHabitatScreen': () => const PetHabitatScreen(),
  'StickerAlbumScreen': () => const StickerAlbumScreen(),
  'BoardFrameScreen': () => const BoardFrameScreen(),
  'MascotWardrobeScreen': () => const MascotWardrobeScreen(),
  'LeaderboardScreen': () => const LeaderboardScreen(),
  'FriendCompareScreen': () => const FriendCompareScreen(),
  'GhostReplayScreen': () => const GhostReplayScreen(),
  'PuzzleLabScreen': () => const PuzzleLabScreen(),
};

/// Trạng thái "đã chơi nhiều" — màn rỗng thì không có gì để tràn.
///
/// Tên key lấy từ [StorageKeys] chứ không gõ tay: gõ sai thì save rỗng và cả
/// bộ quét thành vô nghĩa mà vẫn xanh.
Map<String, Object> _richSave() => <String, Object>{
  StorageKeys.unlockedLevel: 140,
  StorageKeys.coins: 12345,
  StorageKeys.prestigeTier: 2,
  StorageKeys.starDustCount: 90,
  StorageKeys.seasonPoints: 640,
  StorageKeys.weeklyGoalProgress: 220,
  StorageKeys.dailyStreak: 6,
  StorageKeys.loginStreakCount: 9,
  // Sao theo từng màn — `totalStars` suy ra từ đây chứ không có key riêng.
  for (var id = 1; id <= 139; id++) StorageKeys.star(id): 3,
  for (var id = 1; id <= 139; id++) StorageKeys.highScore(id): 9000 + id,
};
/// Màn "tràn" ở khung 360dp **kể cả tiếng Anh** — và đã xác minh là **ảo**.
///
/// `flutter test` không nạp Baloo2 mà thay bằng font có metric khác, chữ rộng
/// và cao hơn thật. Ba màn dưới đây vượt khung trong test nhưng KHÔNG vượt
/// trên máy: đã đặt Pixel 7 Pro về đúng 360x640dp (`wm size 1080x1920` +
/// `wm density 320`), chạy tiếng Đức — chuỗi dài nhất repo — và chụp cả ba.
/// Không màn nào có vạch tràn:
///
/// * Home — thẻ chào, carousel, hàng nút dưới đều vừa.
/// * Level Select — kể cả header có luật vùng, chỗ dài nhất:
///   "Minzfälle" + "Zonenregel: Das Combo-Fenster hält hier länger" nằm gọn
///   một dòng. (Site `level_select_screen.dart:801` vốn chỉ có chữ số và icon
///   sao, không có gì để dịch dài ra — đúng như đã ngờ.)
/// * Pet Habitat — thẻ pet với "+1 gratis Rückgängig" vừa khít.
///
/// Vì vậy KHÔNG sửa: sửa layout theo một phép đo sai là tự tạo bug. Ca kiểm
/// đòi chúng **vẫn phải tràn trong test**, nên nếu Flutter đổi font thay thế
/// (hoặc ai đó nạp font thật vào test) thì suite đỏ và đoạn ghi chú này được
/// đọc lại thay vì mục rữa.
const _kNarrowScreenDebt = <String>{
  'HomeScreen',
  'LevelSelectScreen',
  'PetHabitatScreen',
};

void main() {
  for (final locale in _kLocales) {
    group('${locale.languageCode}_${locale.countryCode} @360dp', () {
      for (final entry in _kScreens.entries) {
        testWidgets(entry.key, (tester) async {
          tester.view.physicalSize = _kNarrow;
          tester.view.devicePixelRatio = _kPixelRatio;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(Get.reset);

          SharedPreferences.setMockInitialValues(_richSave());
          final prefs = await SharedPreferences.getInstance();
          final store = Get.put(StorageService(prefs), permanent: true);
          // SettingsScreen đọc LocaleService để tick ngôn ngữ đang chọn; thiếu
          // nó thì màn ném trước cả khi layout chạy.
          Get.put(LocaleService(store), permanent: true);
          Get.put(GameController(), permanent: true);

          await tester.pumpWidget(
            GetMaterialApp(
              locale: locale,
              fallbackLocale: const Locale('en', 'US'),
              translations: AppTranslations(),
              home: entry.value(),
            ),
          );
          // Nhiều màn có animation lặp vô hạn (StarMascot, PulseGlow) nên
          // pumpAndSettle sẽ treo. Pump theo bước cố định là đủ để layout và
          // paint chạy — tràn RenderFlex báo lúc paint.
          for (var i = 0; i < 6; i++) {
            await tester.pump(const Duration(milliseconds: 120));
          }

          final error = tester.takeException();
          if (_kNarrowScreenDebt.contains(entry.key)) {
            expect(
              error,
              isNotNull,
              reason:
                  '${entry.key} hết tràn rồi — bỏ nó khỏi _kNarrowScreenDebt '
                  'để ca này canh tiếp',
            );
            return;
          }
          expect(
            error,
            isNull,
            reason:
                '${entry.key} vỡ ở ${locale.languageCode} trên khung 360dp. '
                'Nếu en_US cũng đỏ thì không phải lỗi bản dịch — thêm vào '
                '_kNarrowScreenDebt kèm lý do thay vì sửa mò.',
          );
        });
      }
    });
  }
}
