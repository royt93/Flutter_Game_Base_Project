import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pop_star_blast/core/storage_service.dart';
import 'package:pop_star_blast/data/levels.dart';
import 'package:pop_star_blast/data/worlds.dart';
import 'package:pop_star_blast/presentation/controllers/game_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// I81 — `WeatherKind` gắn luật gameplay thật.
///
/// Bất biến quan trọng nhất, và cũng là lý do task này không phải Must:
/// **mọi luật thời tiết chỉ được CỘNG THÊM**. Bàn campaign không refill nên
/// `targetScore` chỉ đạt được nếu neo theo số ô; một luật trừ đi có thể làm cả
/// world thành bất khả thi, mà `levels_achievability_test.dart` mô phỏng bàn
/// màu thuần (không obstacle/ice) nên **không bắt được** loại hồi quy đó.
///
/// Nhóm "an toàn" bên dưới canh đúng chỗ ấy: nếu ai thêm luật trừ đi, test đỏ
/// trước khi kịp phá cân bằng 260 màn.
late GameController ctrl;

Future<void> _boot() async {
  SharedPreferences.setMockInitialValues({});
  final store = await SharedPreferences.getInstance();
  Get.put(StorageService(store), permanent: true);
  ctrl = Get.put(GameController(), permanent: true);
}

/// Màn đầu tiên thuộc world có thời tiết [w].
int _levelWithWeather(WeatherKind w) =>
    kWorlds.firstWhere((x) => x.weather == w).startId;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(Get.reset);

  group('bảng luật', () {
    test('mỗi luật có id/tên/mô tả riêng, không trùng', () {
      final ids = kWeatherRules.values.map((r) => r.id).toList();
      expect(ids.toSet().length, ids.length);
      for (final r in kWeatherRules.values) {
        expect(r.nameKey, isNotEmpty);
        expect(r.descKey, isNotEmpty);
      }
    });

    test('WeatherKind.none không có luật', () {
      expect(kWeatherRules[WeatherKind.none], isNull);
    });

    test('mọi world có thời tiết != none đều tra ra luật hoặc null rõ ràng', () {
      for (final w in kWorlds) {
        final rule = kWeatherRules[w.weather];
        if (w.weather == WeatherKind.none) {
          expect(rule, isNull, reason: 'world ${w.startId}');
        }
        // snow cố ý chưa có luật — xem ghi chú ở `kWeatherRules`.
      }
    });

    test('snow CỐ Ý chưa có luật, không phải quên', () {
      // Ca này là tài liệu sống: nếu ai thêm luật cho snow (tăng ice = luật
      // TRỪ ĐI đầu tiên), họ phải xoá ca này và khi đó buộc phải đọc lý do —
      // bộ mô phỏng achievability chưa mô hình hoá ice.
      expect(kWeatherRules[WeatherKind.snow], isNull);
    });
  });

  group('an toàn: chỉ luật cộng thêm', () {
    test('không luật nào rút ngắn cửa sổ combo', () {
      for (final r in kWeatherRules.values) {
        final w = r.comboWindowOverride;
        if (w == null) continue;
        expect(
          w,
          greaterThanOrEqualTo(GameController.comboWindow),
          reason:
              'luật "${r.id}" rút ngắn combo window → giảm điểm → có thể làm '
              'màn bất khả thi mà achievability test không thấy',
        );
      }
    });

    test('không luật nào giới hạn lượt, ép nhóm tối thiểu hay khoá undo', () {
      for (final r in kWeatherRules.values) {
        expect(r.moveLimit, isNull, reason: r.id);
        expect(r.minGroupSize, isNull, reason: r.id);
        expect(r.disableUndo, isFalse, reason: r.id);
        expect(r.colorCountOverride, isNull, reason: r.id);
        expect(r.gravityOverride, isNull, reason: r.id);
      }
    });

    test('hệ số điểm thưởng luôn >= 1', () {
      for (final r in kWeatherRules.values) {
        final b = r.bigGroupBonus;
        if (b == null) continue;
        expect(b, greaterThanOrEqualTo(1.0), reason: r.id);
      }
    });
  });

  group('tra luật theo màn', () {
    test('màn campaign trả đúng luật của world nó thuộc về', () {
      final id = _levelWithWeather(WeatherKind.bubble);
      expect(weatherRuleForLevel(id)?.id, 'weather_bubble');
      expect(
        weatherRuleForLevel(_levelWithWeather(WeatherKind.spark))?.id,
        'weather_spark',
      );
    });

    test('world thời tiết none -> null', () {
      final id = _levelWithWeather(WeatherKind.none);
      expect(weatherRuleForLevel(id), isNull);
    });

    test('id side-mode (<= 0) -> null, không ăn luật world cuối', () {
      // `worldForLevel` có `orElse: kWorlds.last`, nên thiếu chốt id <= 0 là
      // mọi side-mode âm sẽ nhận luật của world 13.
      for (final id in [0, -1, -9, -100]) {
        expect(weatherRuleForLevel(id), isNull, reason: 'id $id');
      }
    });

    test('TRIPWIRE: world cuối chưa có luật, nên chốt id<=0 hiện chưa chứng minh được', () {
      // Mutation-check nói thẳng: gỡ `if (id <= 0) return null;` mà bộ test vẫn
      // xanh. Không phải vì chốt đó thừa, mà vì world 13 đang là
      // `WeatherKind.none` (cố ý, để không chồng aurora I16) nên
      // `orElse: kWorlds.last` vô tình trả về null.
      //
      // Ca này đỏ ngay khi ai đó gán thời tiết CÓ luật cho world cuối — đúng
      // lúc chốt kia bắt đầu có tác dụng thật. Khi đó: giữ chốt, và thay ca
      // này bằng ca kiểm hành vi thật.
      expect(
        kWeatherRules[kWorlds.last.weather],
        isNull,
        reason:
            'world cuối vừa có luật → chốt `id <= 0` trong weatherRuleForLevel '
            'giờ là tuyến phòng thủ thật, hãy viết ca kiểm nó cho tử tế',
      );
    });

    test('mọi màn campaign đều tra được, không ném', () {
      for (var id = 1; id <= kLevelCount; id++) {
        expect(() => weatherRuleForLevel(id), returnsNormally);
      }
    });
  });

  group('nối vào controller', () {
    test('startLevel gắn đúng luật của world', () async {
      await _boot();
      ctrl.startLevel(_levelWithWeather(WeatherKind.spark));
      expect(ctrl.activeGameplayModifier?.id, 'weather_spark');
      expect(ctrl.activeBigGroupBonus, 1.2);
    });

    test('bubble: cửa sổ combo dài hơn mặc định', () async {
      await _boot();
      ctrl.startLevel(_levelWithWeather(WeatherKind.bubble));
      expect(
        ctrl.activeComboWindowOverride,
        greaterThan(GameController.comboWindow),
      );
    });

    test('world không có luật -> không override gì', () async {
      await _boot();
      ctrl.startLevel(_levelWithWeather(WeatherKind.none));
      expect(ctrl.activeGameplayModifier, isNull);
      expect(ctrl.activeComboWindowOverride, isNull);
      expect(ctrl.activeBigGroupBonus, isNull);
    });

    test('đổi sang world khác thì luật đổi theo', () async {
      await _boot();
      ctrl.startLevel(_levelWithWeather(WeatherKind.spark));
      expect(ctrl.activeBigGroupBonus, isNotNull);

      ctrl.startLevel(_levelWithWeather(WeatherKind.none));
      expect(ctrl.activeBigGroupBonus, isNull);
    });

    test('side-mode KHÔNG ăn luật thời tiết dù vừa chơi campaign', () async {
      await _boot();
      ctrl.startLevel(_levelWithWeather(WeatherKind.spark));
      expect(ctrl.activeGameplayModifier, isNotNull);

      ctrl.startSideMode(GameMode.timeAttack);

      expect(
        ctrl.activeGameplayModifier,
        isNull,
        reason: 'luật world rò sang mode chấm best-score là hỏng mọi kỷ lục',
      );
      expect(ctrl.activeBigGroupBonus, isNull);
    });
  });

  group('điểm thưởng nhóm lớn', () {
    test('nhóm đủ lớn được nhân hệ số', () async {
      await _boot();
      ctrl.startLevel(_levelWithWeather(WeatherKind.spark));
      final threshold = ctrl.activeBigGroupThreshold;

      final gained = ctrl.registerPop(100, groupSize: threshold);

      // Combo đầu tiên = x1, nên phần dôi ra đúng là hệ số thời tiết.
      expect(gained, (100 * 1.2).round());
    });

    test('nhóm nhỏ hơn ngưỡng KHÔNG được thưởng', () async {
      await _boot();
      ctrl.startLevel(_levelWithWeather(WeatherKind.spark));
      final threshold = ctrl.activeBigGroupThreshold;

      final gained = ctrl.registerPop(100, groupSize: threshold - 1);

      expect(gained, 100);
    });

    test('world không có luật: nhóm lớn vẫn tính điểm gốc', () async {
      await _boot();
      ctrl.startLevel(_levelWithWeather(WeatherKind.none));

      expect(ctrl.registerPop(100, groupSize: 12), 100);
    });

    test('thưởng cộng hưởng với combo, không thay thế', () async {
      await _boot();
      ctrl.startLevel(_levelWithWeather(WeatherKind.spark));
      final threshold = ctrl.activeBigGroupThreshold;

      ctrl.registerPop(100, groupSize: threshold); // combo x1
      final second = ctrl.registerPop(100, groupSize: threshold); // combo x1.5

      expect(second, (100 * 1.5 * 1.2).round());
    });
  });
}
