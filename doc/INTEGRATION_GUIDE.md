# Tích hợp `roy_casual_kit` vào game Flutter mới

Hướng dẫn ngắn này dành cho project game tiêu thụ package. Dùng bootstrap có sẵn; không tự `Get.put` lại mọi service.

## 1. Thêm package

Package phát hành:

```bash
flutter pub add roy_casual_kit
```

Phát triển local:

```yaml
dependencies:
  roy_casual_kit:
    path: ../roy_casual_kit
```

Sau đó:

```bash
flutter pub get
```

## 2. Bootstrap một lần

```dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/roy_casual_kit.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await RoyCasualKit.initialize(
    config: const RoyCasualKitConfig(
      modules: {
        RoyCasualKitModule.storage,
        RoyCasualKitModule.locale,
        RoyCasualKitModule.audio,
        RoyCasualKitModule.lifecycle,
        RoyCasualKitModule.performance,
      },
    ),
  );

  await AudioManager.maybe?.init();
  AudioManager.maybe?.startBgm();
  runApp(const MyGameApp());
}

class MyGameApp extends StatelessWidget {
  const MyGameApp({super.key});

  @override
  Widget build(BuildContext context) => GetMaterialApp(
    translations: AppTranslations(),
    locale: LocaleService.maybe?.current.value,
    home: const GameHomeScreen(),
  );
}
```

Chỉ bật module game thật cần. `RoyCasualKit.initialize` idempotent; module lỗi được trả trong result thay vì làm app trắng màn hình.

## 3. Tạo core gameplay loop

```dart
final energy = Get.put(
  EnergyService(
    maxEnergy: 5,
    refillInterval: const Duration(minutes: 10),
  ),
  permanent: true,
);
final wallet = Get.put(
  EconomyWallet(storage: StorageService.to),
  permanent: true,
);
final progression = Get.put(
  PlayerProgressionService(
    storage: StorageService.to,
    levelCurve: const [
      LevelDefinition(level: 1, xpToNext: 100),
      LevelDefinition(level: 2, xpToNext: 200),
      LevelDefinition(level: 3, xpToNext: 0),
    ],
  ),
  permanent: true,
);

Future<bool> completeRound(int score) async {
  if (!energy.consumeEnergy()) return false;

  await progression.grantXp(
    amount: 40,
    transactionId: 'round_xp_$score',
  );
  await wallet.earn(
    currency: 'coins',
    amount: 30,
    transactionId: 'round_coins_$score',
  );
  return true;
}
```

`transactionId` phải duy nhất và ổn định cho cùng một phần thưởng. Không dùng thời gian nếu server có ID giao dịch riêng.

## 4. Nối Flame với service

Giữ luật economy ngoài `FlameGame`. Flame chỉ emit gameplay event; Flutter screen/controller xử lý reward:

```dart
final events = GameEventBus();
final game = RoyGame(eventBus: events);

late final StreamSubscription<GameEvent> tapSubscription;

void bindGameplay() {
  tapSubscription = events.subscribe<CircleTappedEvent>((event) {
    // cập nhật score/combo/quest; không nhét ví tiền vào Component
  });
}

Future<void> disposeGameplay() async {
  await tapSubscription.cancel();
  await events.dispose();
}
```

Mẫu chạy đầy đủ: `example/lib/screens/game_demo_screen.dart`.

## 5. Save và offline earnings

```dart
final offline = Get.put(OfflineProgressionService(), permanent: true);

Future<void> claimOfflineCoins() async {
  final amount = (await offline.claim(2.0)).toInt();
  if (amount == 0) return;
  await EconomyWallet.maybe!.earn(
    currency: 'coins',
    amount: amount,
    transactionId: 'offline_${DateTime.now().millisecondsSinceEpoch}',
  );
}
```

Dữ liệu có schema dùng `VersionedJsonStore`; save quan trọng dùng `signExport`/`verifyAndStrip`; cloud dùng `CloudSaveProvider` adapter.

## 6. Audio và haptics

Khai báo audio game trong `pubspec.yaml`:

```yaml
flutter:
  assets:
    - assets/audio/
```

Phát SFX từ app consumer:

```dart
await AudioManager.maybe?.playSfx('audio/tap.ogg', volume: 0.45);
await AudioManager.maybe?.playSfx('audio/victory.ogg', duck: true);
HapticChoreographer().play(HapticPattern.reward);
```

`duck: true` hạ BGM tạm thời. Mute dùng `AudioManager.toggleMute()`; không gọi `HapticFeedback` trực tiếp.

## 7. Cắm adapter nền tảng

Core không phụ thuộc vendor SDK. App consumer triển khai seam rồi đăng ký trước màn hình dùng nó:

```dart
Get.put<AnalyticsProvider>(myAnalyticsAdapter, permanent: true);
Get.put<CrashReporter>(myCrashAdapter, permanent: true);
Get.put<CloudSaveProvider>(myCloudAdapter, permanent: true);
Get.put<PurchaseSeam>(myPurchaseAdapter, permanent: true);
Get.put<AdRewardSeam>(myRewardedAdAdapter, permanent: true);
```

Kiểm tra adapter:

```dart
final report = await PluginAdapterConformanceSuite.verifyAdRewardSeam(
  myRewardedAdAdapter,
);
assert(report.passed, report.failures.join(', '));
```

`applovin_admob_sdk` chưa tích hợp theo chủ đích. Khi làm, adapter nằm trong app consumer/example, không nằm trong core kit.

## 8. Checklist trước release

```bash
flutter analyze
flutter test --exclude-tags slow
cd example
flutter analyze
flutter test --exclude-tags slow
flutter build apk --release
```

Kiểm tra thiết bị thật:

1. Chơi round: trừ 1 Energy.
2. Win: cộng XP, coins, score đúng một lần.
3. Kill/reopen: wallet, progression, save còn nguyên.
4. Background/resume: BGM pause/resume; game session không lệch trạng thái.
5. Mute, haptics, font scale, locale dài không overflow.

## File mẫu

- `example/lib/main.dart`: bootstrap, lifecycle, error handler.
- `example/lib/screens/game_demo_screen.dart`: Flame + Energy + XP + wallet + leaderboard.
- `example/lib/screens/level_progression_screen.dart`: progression/offline earnings.
- `example/lib/screens/save_cloud_screen.dart`: save slot, cloud fake, backup/restore.
- `example/lib/screens/monetization_screen.dart`: purchase/ad seams dùng fake adapter.
- `example/test/game_demo_screen_test.dart`: test core gameplay loop không cần thiết bị.
