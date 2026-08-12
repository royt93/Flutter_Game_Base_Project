import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pop_star_blast/core/app_translations.dart';
import 'package:pop_star_blast/core/storage_service.dart';
import 'package:pop_star_blast/data/constellations.dart';
import 'package:pop_star_blast/data/levels.dart';
import 'package:pop_star_blast/presentation/controllers/game_controller.dart';
import 'package:pop_star_blast/presentation/screens/sky_shrine_screen.dart';
import 'package:pop_star_blast/presentation/widgets/pressable_scale.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// `SkyShrineScreen` (I64) — chưa có test widget nào.
///
/// `test/data/constellations_test.dart` phủ `isConstellationLit`, tức là đúng
/// một phép so sánh. Thứ chưa ai kiểm là phần khác thường của màn này: **nó
/// phát thưởng ngay trong `build`**.
///
/// ```dart
/// if (isLit && !isSeedClaimed) {
///   WidgetsBinding.instance.addPostFrameCallback((_) {
///     gameCtrl.claimStarSeedForConstellation(index);
///   });
/// }
/// ```
///
/// Side effect trong `build` bên trong `Obx` mà lại sửa đúng biến `Obx` đang
/// nghe (`claimedStarSeedMask`) — chỉ dừng được nhờ guard `isSeedClaimed`.
/// Sai một chút là vòng lặp rebuild vô hạn hoặc phát Star Seed nhiều lần.
late GameController ctrl;

Future<void> _pump(
  WidgetTester tester, {
  Map<String, Object> prefs = const {},
  int? stars,
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final store = await SharedPreferences.getInstance();
  Get.put(StorageService(store), permanent: true);
  ctrl = Get.put(GameController(), permanent: true);
  if (stars != null) ctrl.totalStars.value = stars;

  await tester.pumpWidget(
    GetMaterialApp(
      translations: AppTranslations(),
      locale: const Locale('en'),
      fallbackLocale: const Locale('en'),
      home: const SkyShrineScreen(),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
}

/// Sao rải trên các màn campaign thật (tối đa 3 sao/màn) để `_recomputeTotalStars`
/// tự cộng ra [stars] — dùng khi cần kiểm cả đường nạp, không chỉ gán Rx.
Map<String, Object> _starsPrefs(int stars) {
  final out = <String, Object>{};
  var left = stars;
  var id = 1;
  while (left > 0 && id <= kLevelCount) {
    final s = left >= 3 ? 3 : left;
    out[StorageKeys.star(id)] = s;
    left -= s;
    id++;
  }
  return out;
}

Constellation get _first => kConstellations.first;
Constellation get _second => kConstellations[1];

Finder _card(Constellation c) => find.ancestor(
  of: find.text(c.nameKey.tr),
  matching: find.byType(Container),
);

/// Nút gắn/tháo hào quang của chòm sao [c]. Chỉ tồn tại khi chòm đã sáng.
Finder _auraButton(Constellation c) =>
    find.descendant(of: _card(c).last, matching: find.byType(PressableScale));

Future<void> _tapAura(WidgetTester tester, Constellation c) async {
  final f = _auraButton(c);
  await tester.ensureVisible(f.first);
  await tester.pump(const Duration(milliseconds: 120));
  await tester.tap(f.first);
  await tester.pump(const Duration(milliseconds: 250));
}

void main() {
  tearDown(Get.reset);

  group('dựng màn hình', () {
    testWidgets('render được, không ném', (tester) async {
      await _pump(tester);
      expect(find.byType(SkyShrineScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('liệt kê đủ mọi chòm sao, kể cả chưa sáng', (tester) async {
      await _pump(tester);
      for (final c in kConstellations) {
        // `StrokeText` vẽ 2 lớp Text chồng nhau (viền + ruột) nên tên chòm
        // luôn trúng 2 widget — đếm chính xác ở đây là đếm chi tiết render.
        expect(
          find.text(c.nameKey.tr),
          findsWidgets,
          reason: 'thiếu chòm "${c.id}"',
        );
      }
    });

    testWidgets('chòm chưa sáng hiện mốc sao còn thiếu', (tester) async {
      await _pump(tester, stars: 0);
      expect(
        find.text(
          'sky_shrine_stars_req'.trParams({
            'req': '${_first.starsRequired}',
            'curr': '0',
          }),
        ),
        findsOneWidget,
      );
      expect(find.text('sky_shrine_lit'.tr), findsNothing);
    });

    testWidgets('tổng sao đọc từ save thật, không chỉ từ Rx', (tester) async {
      await _pump(tester, prefs: _starsPrefs(_first.starsRequired));
      expect(ctrl.totalStars.value, _first.starsRequired);
      expect(find.text('sky_shrine_lit'.tr), findsOneWidget);
    });
  });

  group('chòm chưa sáng', () {
    testWidgets('không có nút hào quang', (tester) async {
      await _pump(tester, stars: _first.starsRequired - 1);
      expect(find.text('sky_shrine_aura_equip'.tr), findsNothing);
      expect(find.text('sky_shrine_aura_active'.tr), findsNothing);
    });

    testWidgets('KHÔNG phát Star Seed', (tester) async {
      await _pump(tester, stars: _first.starsRequired - 1);
      expect(
        ctrl.starSeedCount.value,
        0,
        reason: 'thiếu đúng 1 sao vẫn không được nhận hạt',
      );
      expect(ctrl.isStarSeedClaimed(0), isFalse);
    });
  });

  group('phát Star Seed khi mở màn hình', () {
    testWidgets('chòm vừa đủ sao -> tự nhận 1 hạt', (tester) async {
      await _pump(tester, stars: _first.starsRequired);

      expect(ctrl.starSeedCount.value, 1);
      expect(ctrl.isStarSeedClaimed(0), isTrue);
      expect(find.text('sky_shrine_lit'.tr), findsOneWidget);
    });

    testWidgets('nhiều chòm cùng sáng -> nhận đủ từng hạt một', (tester) async {
      await _pump(tester, stars: _second.starsRequired);

      expect(ctrl.starSeedCount.value, 2);
      expect(ctrl.isStarSeedClaimed(0), isTrue);
      expect(ctrl.isStarSeedClaimed(1), isTrue);
      expect(ctrl.isStarSeedClaimed(2), isFalse);
    });

    testWidgets('đã nhận rồi -> mở lại không cộng thêm', (tester) async {
      // Đây là guard duy nhất chặn phát thưởng lặp: `build` chạy lại mỗi lần
      // `Obx` bắn, mà chính lời gọi claim lại sửa biến `Obx` đang nghe.
      await _pump(
        tester,
        prefs: {
          StorageKeys.claimedStarSeedMask: 1,
          StorageKeys.starSeedCount: 1,
        },
        stars: _first.starsRequired,
      );

      expect(ctrl.starSeedCount.value, 1);
    });

    testWidgets('rebuild nhiều lần vẫn đúng 1 hạt/chòm', (tester) async {
      await _pump(tester, stars: _first.starsRequired);
      final after = ctrl.starSeedCount.value;

      // Ép Obx bắn lại vài lần: nếu guard hỏng thì số hạt tăng dần.
      for (var i = 0; i < 5; i++) {
        ctrl.totalStars.value = _first.starsRequired + i;
        await tester.pump(const Duration(milliseconds: 120));
      }

      expect(ctrl.starSeedCount.value, after);
      expect(tester.takeException(), isNull);
    });

    testWidgets('số hạt được persist ngay, không đợi thoát màn', (
      tester,
    ) async {
      await _pump(tester, stars: _first.starsRequired);

      final store = StorageService.to;
      expect(store.getInt(StorageKeys.starSeedCount), 1);
      expect(store.getInt(StorageKeys.claimedStarSeedMask), 1);
    });

    testWidgets('sao tăng dần -> chòm sau sáng thì nhận thêm hạt', (
      tester,
    ) async {
      await _pump(tester, stars: _first.starsRequired);
      expect(ctrl.starSeedCount.value, 1);

      ctrl.totalStars.value = _second.starsRequired;
      await tester.pump(const Duration(milliseconds: 250));

      expect(ctrl.starSeedCount.value, 2);
    });
  });

  group('hào quang', () {
    testWidgets('mặc định không gắn hào quang nào', (tester) async {
      await _pump(tester, stars: _first.starsRequired);
      expect(ctrl.activeSkyAura.value, 'default');
      expect(find.text('sky_shrine_aura_equip'.tr), findsOneWidget);
      expect(find.text('sky_shrine_aura_active'.tr), findsNothing);
    });

    testWidgets('bấm để gắn, nhãn đổi sang "đang dùng", persist', (
      tester,
    ) async {
      await _pump(tester, stars: _first.starsRequired);

      await _tapAura(tester, _first);

      expect(ctrl.activeSkyAura.value, _first.auraVariant);
      expect(
        StorageService.to.getString(StorageKeys.activeSkyAura),
        _first.auraVariant,
      );
      expect(find.text('sky_shrine_aura_active'.tr), findsOneWidget);
    });

    testWidgets('bấm lại là tháo, về default', (tester) async {
      await _pump(tester, stars: _first.starsRequired);

      await _tapAura(tester, _first);
      await _tapAura(tester, _first);

      expect(ctrl.activeSkyAura.value, 'default');
      expect(find.text('sky_shrine_aura_equip'.tr), findsOneWidget);
    });

    testWidgets('gắn chòm khác thì chòm cũ tự nhả, chỉ 1 cái đang dùng', (
      tester,
    ) async {
      await _pump(tester, stars: _second.starsRequired);

      await _tapAura(tester, _first);
      await _tapAura(tester, _second);

      expect(ctrl.activeSkyAura.value, _second.auraVariant);
      expect(
        find.text('sky_shrine_aura_active'.tr),
        findsOneWidget,
        reason: 'hai chòm cùng báo "đang dùng" là hiển thị nói dối',
      );
    });
  });

  group('save hỏng / sửa tay', () {
    testWidgets('mask lệch pha số hạt -> không sửa ngược, không ném', (
      tester,
    ) async {
      // Mask nói "đã nhận chòm 0" nhưng số hạt là 0. Đây là save không nhất
      // quán (kill app giữa 2 lệnh ghi). Màn hình phải sống được và KHÔNG tự
      // ý phát bù — phát bù là đường farm: xoá số hạt rồi mở lại màn.
      await _pump(
        tester,
        prefs: {StorageKeys.claimedStarSeedMask: 1},
        stars: _first.starsRequired,
      );

      expect(ctrl.starSeedCount.value, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('hào quang trong save trỏ chòm CHƯA sáng: hiện đang giữ', (
      tester,
    ) async {
      // Ghi lại đúng như đo được, không phải như mong muốn.
      //
      // Khác với khung viền board (`activeBoardFrame` có getter revalidate và
      // fallback về classic), `activeSkyAura` được nạp thẳng từ storage và
      // KHÔNG đối chiếu lại với chòm đã sáng — `setActiveSkyAura` cũng nhận
      // mọi chuỗi. Sửa tay save là dùng được hào quang chưa mở.
      //
      // Chưa vá vì thuần cosmetic và cần quyết định sản phẩm (fallback về
      // default hay giữ lại như khung theo mùa của [[I73]]). Test này chốt
      // hành vi hiện tại để lần sửa sau là một thay đổi có chủ ý.
      await _pump(
        tester,
        prefs: {StorageKeys.activeSkyAura: kConstellations.last.auraVariant},
        stars: 0,
      );

      expect(ctrl.activeSkyAura.value, kConstellations.last.auraVariant);
      expect(
        find.text('sky_shrine_aura_active'.tr),
        findsNothing,
        reason: 'chòm chưa sáng thì không dựng nút, nên UI không lộ ra',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('setActiveSkyAura nhận mọi chuỗi, kể cả rác', (tester) async {
      await _pump(tester, stars: _first.starsRequired);

      ctrl.setActiveSkyAura('khong_ton_tai');

      expect(ctrl.activeSkyAura.value, 'khong_ton_tai');
      expect(
        find.text('sky_shrine_aura_active'.tr),
        findsNothing,
        reason: 'không chòm nào khớp thì không chòm nào được báo đang dùng',
      );
    });
  });
}
