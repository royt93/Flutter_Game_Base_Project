import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/core/app_translations.dart';
import 'package:roy_casual_kit/core/game_accessibility_announcer.dart';
import 'package:roy_casual_kit/core/game_event_bus.dart';
import 'package:roy_casual_kit/core/locale_service.dart';
import 'package:roy_casual_kit/core/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late GameEventBus bus;
  late List<String> spoken;
  late int nowMs;
  late Locale locale;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    Get.put(StorageService(await SharedPreferences.getInstance()));
    bus = GameEventBus();
    spoken = [];
    nowMs = 0;
    locale = const Locale('en');
  });

  tearDown(() async {
    await bus.dispose();
    Get.reset();
  });

  GameAccessibilityAnnouncer makeAnnouncer({
    bool Function()? isEnabled,
    Future<void> Function(String)? announce,
  }) => GameAccessibilityAnnouncer(
    eventBus: bus,
    announce: announce ?? (message) async => spoken.add(message),
    locale: () => locale,
    isEnabled: isEnabled,
    nowMs: () => nowMs,
    throttleWindow: const Duration(milliseconds: 500),
  );

  test('không truyền nowMs: dùng đồng hồ mặc định, vẫn throttle cùng category', () async {
    final announcer = GameAccessibilityAnnouncer(
      eventBus: bus,
      announce: (message) async => spoken.add(message),
      locale: () => locale,
      isEnabled: () => true,
      throttleWindow: const Duration(minutes: 5),
    );
    addTearDown(announcer.dispose);
    for (var i = 0; i < 2; i++) {
      bus.emit(
        GameAccessibilityEvent(
          category: GameAccessibilityCategory.levelUp,
          translationKey: 'a11y_level_up',
          parameters: const {'value': '7'},
        ),
      );
      await Future<void>.delayed(Duration.zero);
    }
    expect(spoken, hasLength(1));
  });

  test('fake announcer nhận đúng text locale en + params', () async {
    final announcer = makeAnnouncer();

    bus.emit(
      GameAccessibilityEvent(
        category: GameAccessibilityCategory.levelUp,
        translationKey: 'a11y_level_up',
        parameters: const {'value': '7'},
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(spoken, ['Level up! Now level 7.']);
    await announcer.dispose();
  });

  test('fake announcer nhận đúng text locale vi + params', () async {
    locale = const Locale('vi');
    final announcer = makeAnnouncer();

    bus.emit(
      GameAccessibilityEvent(
        category: GameAccessibilityCategory.reward,
        translationKey: 'a11y_reward_granted',
        parameters: const {'value': '50 xu'},
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(spoken, ['Nhận thưởng: 50 xu.']);
    await announcer.dispose();
  });

  test(
    'locale không hỗ trợ -> fallback English, không announce raw key',
    () async {
      locale = const Locale('fr');
      final announcer = makeAnnouncer();

      bus.emit(
        GameAccessibilityEvent(
          category: GameAccessibilityCategory.lives,
          translationKey: 'a11y_lives_changed',
          parameters: const {'value': '3'},
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(spoken, ['Lives: 3.']);
      await announcer.dispose();
    },
  );

  test(
    'burst cùng category trong cửa sổ -> chỉ event đầu announce; category khác vẫn announce ngay',
    () async {
      final announcer = makeAnnouncer();

      bus.emit(
        GameAccessibilityEvent(
          category: GameAccessibilityCategory.levelUp,
          translationKey: 'a11y_level_up',
          parameters: const {'value': '2'},
        ),
      );
      bus.emit(
        GameAccessibilityEvent(
          category: GameAccessibilityCategory.levelUp,
          translationKey: 'a11y_level_up',
          parameters: const {'value': '3'},
        ),
      );
      bus.emit(
        GameAccessibilityEvent(
          category: GameAccessibilityCategory.reward,
          translationKey: 'a11y_reward_granted',
          parameters: const {'value': '10 gems'},
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(spoken, ['Level up! Now level 2.', 'Reward received: 10 gems.']);
      await announcer.dispose();
    },
  );

  test('cùng category announce lại sau throttleWindow', () async {
    final announcer = makeAnnouncer();

    bus.emit(
      GameAccessibilityEvent(
        category: GameAccessibilityCategory.lives,
        translationKey: 'a11y_lives_changed',
        parameters: const {'value': '4'},
      ),
    );
    await Future<void>.delayed(Duration.zero);
    nowMs = 500;
    bus.emit(
      GameAccessibilityEvent(
        category: GameAccessibilityCategory.lives,
        translationKey: 'a11y_lives_changed',
        parameters: const {'value': '3'},
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(spoken, ['Lives: 4.', 'Lives: 3.']);
    await announcer.dispose();
  });

  test('disabled path không gọi announcer callback', () async {
    final announcer = makeAnnouncer(isEnabled: () => false);

    bus.emit(
      GameAccessibilityEvent(
        category: GameAccessibilityCategory.reward,
        translationKey: 'a11y_reward_granted',
        parameters: const {'value': '1 gem'},
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(spoken, isEmpty);
    await announcer.dispose();
  });

  test(
    'default enabled path tôn trọng StorageKeys.gameA11yAnnouncerEnabled=false',
    () async {
      await StorageService.to.setBool(
        StorageKeys.gameA11yAnnouncerEnabled,
        false,
      );
      final announcer = makeAnnouncer();

      bus.emit(
        GameAccessibilityEvent(
          category: GameAccessibilityCategory.reward,
          translationKey: 'a11y_reward_granted',
          parameters: const {'value': '1 gem'},
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(spoken, isEmpty);
      await announcer.dispose();
    },
  );

  test(
    'unknown translation key bị drop, không đọc raw key cho screen reader',
    () async {
      final announcer = makeAnnouncer();

      bus.emit(
        GameAccessibilityEvent(
          category: GameAccessibilityCategory.custom,
          translationKey: 'missing_key',
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(spoken, isEmpty);
      await announcer.dispose();
    },
  );

  test(
    'dispose cancel subscription: emit sau dispose không announce',
    () async {
      final announcer = makeAnnouncer();
      await announcer.dispose();

      bus.emit(
        GameAccessibilityEvent(
          category: GameAccessibilityCategory.reward,
          translationKey: 'a11y_reward_granted',
          parameters: const {'value': '1 gem'},
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(spoken, isEmpty);
    },
  );

  test(
    'announce callback throw bị nuốt, không làm crash gameplay bus',
    () async {
      final announcer = makeAnnouncer(
        announce: (_) async => throw StateError('platform unavailable'),
      );

      bus.emit(
        GameAccessibilityEvent(
          category: GameAccessibilityCategory.reward,
          translationKey: 'a11y_reward_granted',
          parameters: const {'value': '1 gem'},
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(spoken, isEmpty);
      await announcer.dispose();
    },
  );

  test('audit fix: isEnabled seam ném lỗi -> bị nuốt, không lọt ra ngoài như '
      'unhandled async error (chỉ announce() cũ được bọc try/catch, '
      'isEnabled/locale/nowMs chạy TRƯỚC try nên throw của chúng thoát ra '
      'ngoài scope async _onEvent chưa await gì)', () async {
    final announcer = makeAnnouncer(
      isEnabled: () => throw StateError('boom from isEnabled'),
    );

    await runZonedGuarded(
      () async {
        bus.emit(
          GameAccessibilityEvent(
            category: GameAccessibilityCategory.reward,
            translationKey: 'a11y_reward_granted',
            parameters: const {'value': '1 gem'},
          ),
        );
        await Future<void>.delayed(Duration.zero);
      },
      (error, stack) {
        fail('isEnabled throw phải bị nuốt nội bộ, không lọt ra zone: $error');
      },
    );

    expect(spoken, isEmpty);
    await announcer.dispose();
  });

  test(
    'audit fix: locale seam ném lỗi -> bị nuốt, không crash gameplay bus',
    () async {
      final announcer = GameAccessibilityAnnouncer(
        eventBus: bus,
        announce: (message) async => spoken.add(message),
        locale: () => throw StateError('boom from locale'),
        nowMs: () => nowMs,
        throttleWindow: const Duration(milliseconds: 500),
      );

      var caughtOutside = false;
      await runZonedGuarded(() async {
        bus.emit(
          GameAccessibilityEvent(
            category: GameAccessibilityCategory.reward,
            translationKey: 'a11y_reward_granted',
            parameters: const {'value': '1 gem'},
          ),
        );
        await Future<void>.delayed(Duration.zero);
      }, (error, stack) => caughtOutside = true);

      expect(caughtOutside, isFalse);
      expect(spoken, isEmpty);
      await announcer.dispose();
    },
  );

  test(
    'audit fix: nowMs seam ném lỗi -> bị nuốt, không crash gameplay bus',
    () async {
      final announcer = GameAccessibilityAnnouncer(
        eventBus: bus,
        announce: (message) async => spoken.add(message),
        locale: () => locale,
        nowMs: () => throw StateError('boom from nowMs'),
        throttleWindow: const Duration(milliseconds: 500),
      );

      var caughtOutside = false;
      await runZonedGuarded(() async {
        bus.emit(
          GameAccessibilityEvent(
            category: GameAccessibilityCategory.lives,
            translationKey: 'a11y_lives_changed',
            parameters: const {'value': '1'},
          ),
        );
        await Future<void>.delayed(Duration.zero);
      }, (error, stack) => caughtOutside = true);

      expect(caughtOutside, isFalse);
      expect(spoken, isEmpty);
      await announcer.dispose();
    },
  );

  test('audit fix: param value chứa cú pháp {key} của param khác không bị '
      'double-substitute (thay thế phải dựa trên template gốc, không dựa '
      'trên kết quả đã thay thế dở dang)', () async {
    final announcer = makeAnnouncer();

    bus.emit(
      GameAccessibilityEvent(
        category: GameAccessibilityCategory.reward,
        translationKey: 'a11y_reward_granted',
        // Template chỉ có {value}. Giá trị của `value` chứa literal
        // "{extra}", còn map có thêm key extra. Implementation cũ lặp
        // replaceAll tuần tự: thay {value} trước làm "{extra}" mới xuất hiện
        // trong message, rồi vòng lặp extra thay nhầm literal đó thành "Z".
        parameters: const {'value': 'a {extra} b', 'extra': 'Z'},
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(spoken, ['Reward received: a {extra} b.']);
    await announcer.dispose();
  });

  test('constructor/event validation fail fast', () {
    expect(
      () => GameAccessibilityAnnouncer(
        eventBus: bus,
        announce: (_) async {},
        throttleWindow: const Duration(milliseconds: -1),
      ),
      throwsArgumentError,
    );
    expect(
      () => GameAccessibilityEvent(
        category: GameAccessibilityCategory.custom,
        translationKey: '',
      ),
      throwsArgumentError,
    );
  });

  test(
    'event defensive-copy parameters, caller mutate sau construct không đổi text',
    () async {
      final params = <String, String>{'value': 'before'};
      final event = GameAccessibilityEvent(
        category: GameAccessibilityCategory.reward,
        translationKey: 'a11y_reward_granted',
        parameters: params,
      );
      params['value'] = 'after';
      final announcer = makeAnnouncer();

      bus.emit(event);
      await Future<void>.delayed(Duration.zero);

      expect(spoken, ['Reward received: before.']);
      await announcer.dispose();
    },
  );

  test(
    'không truyền locale seam -> mặc định đọc LocaleService.maybe.current',
    () async {
      Get.put(LocaleService(StorageService.to));
      await LocaleService.maybe!.change(const Locale('vi'));
      final announcer = GameAccessibilityAnnouncer(
        eventBus: bus,
        announce: (message) async => spoken.add(message),
        nowMs: () => nowMs,
        throttleWindow: const Duration(milliseconds: 500),
      );

      bus.emit(
        GameAccessibilityEvent(
          category: GameAccessibilityCategory.lives,
          translationKey: 'a11y_lives_changed',
          parameters: const {'value': '2'},
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(spoken, ['Số mạng: 2.']);
      await announcer.dispose();
    },
  );

  test('AppTranslations en/vi parity vẫn giữ sau khi thêm a11y keys', () {
    final keys = AppTranslations().keys;
    expect(keys['en']!.keys.toSet(), keys['vi']!.keys.toSet());
  });
}
