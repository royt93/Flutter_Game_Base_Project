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

## Orientation cho widget `common/`

Widget được export từ `common_widgets.dart` có viewport sweep ở landscape 568×320 và 640×320; text scale 2.0 được kiểm ở 568×320 cùng viewport compact 320×480. Sweep kiểm layout/overflow, không kiểm thao tác xoay thiết bị thật. Consumer app có thể khóa orientation bằng `SystemChrome.setPreferredOrientations`; cần cho phép landscape trong cấu hình nền tảng nếu muốn xoay trên thiết bị.

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

## 4b. Wheel: `backgroundColor` bắt buộc

`WheelSpinner` và `CoinMultiplierWheel` yêu cầu `backgroundColor` **đục hoàn toàn** (alpha 1.0, nếu không constructor ném `ArgumentError`). Wheel tự vẽ nền đó dưới từng sector, nên chữ nhãn được tính tương phản trên đúng màu hiển thị:

```dart
WheelSpinner(
  backgroundColor: NeonTheme.card,        // màu thật phía sau wheel
  segments: segments,
  controller: controller,
  onSpinEnd: onSpinEnd,
);
CoinMultiplierWheel(backgroundColor: NeonTheme.card);
```

- Nhãn tự chọn chữ đen hoặc trắng theo màu sector đã trộn alpha trên `backgroundColor` để đạt WCAG AA (4.5:1). Màu sector của bạn không bị đổi.
- `contrastFindings` trả về nhãn còn dưới 4.5:1 (ví dụ để cảnh báo trong test của game).
- `WheelSpinner` không còn `const`. `WheelSpinnerPainter` dùng trực tiếp cũng cần `backgroundColor` và vẫn vẽ nhãn trắng cố định.

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

## 5b. Service tuỳ chọn khác (đăng ký thủ công)

Bảy service dưới đây không nằm trong `RoyCasualKitModule`; đăng ký bằng `Get.put(x, permanent: true)` khi cần. Trong test, gọi `Get.reset` ở `tearDown`.

**Cooldown bền vững** — `PersistentCooldownService` lưu thời điểm kết thúc theo `key`, không có timer nền; `start` ném `ArgumentError` với key rỗng hoặc thời lượng <= 0.

```dart
final cooldown = Get.put(PersistentCooldownService(), permanent: true);
cooldown.start('booster', const Duration(minutes: 5));
final left = cooldown.remainingOf('booster');
cooldown.cancel('booster');
```

**Đồng ý quyền riêng tư** — `ConsentStateService` mặc định `unknown`, nên `isGranted` là `false` cho tới khi người chơi chọn; hạ `policyVersion` thấp hơn bản đã lưu coi như chưa quyết định.

```dart
final consent = Get.put(ConsentStateService(policyVersion: 1), permanent: true);
consent.grant(ConsentCategory.analytics);
if (consent.isGranted(ConsentCategory.analytics)) { /* bật analytics */ }
```

**Phiên chơi** — `AppSessionTracker` đo phiên và thời gian foreground (timeout mặc định 30 phút); `analyticsContext()` trả map rỗng khi chưa có consent analytics.

```dart
Get.put(AppSessionTracker(), permanent: true);
final ctx = AppSessionTracker.maybe?.analyticsContext() ?? const {};
```

**Đồng hồ game** — `GameTimeController` cộng `dt` thành các bước cố định, im lặng khi `session` đang paused.

```dart
final time = GameTimeController();
final steps = time.tick(0.016);
```

**Checkpoint** — `CheckpointCoordinator(storage: ...)` gom snapshot của từng participant; `requestCheckpoint()` debounce, `critical: true` lưu ngay, `flushNow()` ép lưu, `restoreLatest()` khôi phục (có thế hệ dự phòng).

```dart
final cp = CheckpointCoordinator(storage: StorageService.to);
cp.registerParticipant(
  'game',
  snapshot: () => state.toJson(),
  restore: (data) => state.load(data),
);
await cp.requestCheckpoint();
```

**Hàng đợi offline** — `OfflineOutboxService` xếp thay đổi cục bộ rồi `drain()` đẩy qua `uploader`. `enqueue()`/`resolveManual()` là API đồng bộ best-effort: cập nhật memory ngay và lên lịch ghi storage, nhưng không thể báo lỗi ghi xảy ra sau khi hàm trả về. Dùng `enqueueDurably()`/`resolveManualDurably()` để chờ ghi snapshot; `SdkSuccess` xác nhận lần ghi đó hoàn tất, lỗi trả `SdkFailure(storage)`. Mỗi mục cần `idempotencyKey` không rỗng; backend nên dedupe retry bằng cùng key (at-least-once, không phải exactly-once).

```dart
final outbox = Get.put(
  OfflineOutboxService(
    storage: StorageService.to,
    uploader: (payload, idempotencyKey) async {
      // gọi server của bạn; trả SyncAck() khi thành công
      return const SyncAck();
    },
  ),
  permanent: true,
);
final queued = await outbox.enqueueDurably(
  idempotencyKey: 'score_42',
  payload: {'score': 42},
);
if (queued.isSuccess) await outbox.drain();
```

`enqueueDurably()`/`resolveManualDurably()` đợi ghi snapshot và trả `SdkFailure(storage)` nếu ghi thất bại. `enqueue()`/`resolveManual()` vẫn đồng bộ, cập nhật memory và ghi best-effort; không thể báo lỗi ghi xảy ra sau khi hàm trả về. Backend nên dedupe retry theo cùng `idempotencyKey`; outbox đảm bảo at-least-once, không đảm bảo exactly-once.

**Giao dịch thưởng** — `RewardTransactionPipeline` thực thi kế hoạch thưởng idempotent trên ví: `preview(source:, transactionId:, currencyLines:, itemLines:)` trả `RewardPlan`, rồi `executePlan`; `resumePending()` hoàn tất giao dịch dở sau khi app bị kill. Ví dụ đăng ký (ví + kho đồ): `example/lib/screens/widget_showcase_screen.dart` quanh dòng 786, dùng `RewardTransactionPipeline.withInventory(wallet: ..., inventory: ...)`.

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
```

Kiểm tra adapter:

```dart
final report = await PluginAdapterConformanceSuite.verifyPurchaseSeam(
  myPurchaseAdapter,
);
assert(report.passed, report.failures.join(', '));
```

Kit không có tính năng quảng cáo (đã gỡ ở 0.8.0): nếu game cần ad, tích hợp SDK riêng trong app consumer, không đưa vào core kit.

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
