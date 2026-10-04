import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/core/app_translations.dart';
import 'package:roy_casual_kit/core/game_session_controller.dart';
import 'package:roy_casual_kit/presentation/widgets/common/common_button.dart';
import 'package:roy_casual_kit/presentation/widgets/common/pause_overlay.dart';

// CommonButton vẽ label qua StrokeText (2 lớp Text chồng nhau: stroke +
// fill) — _button('Resume') sẽ ambiguous. Dùng finder theo CommonButton
// thay vì text trực tiếp cho mọi nút (cùng lý do common_button_test.dart).
Finder _button(String label) => find.widgetWithText(CommonButton, label);

// BUG-94: GetMaterialApp (không MaterialApp trơn) — mặc định dịch 'Paused'/
// 'Resume'/... giờ đi qua `.tr`, cần GetX translations binding thật mới
// resolve đúng thay vì hiện nguyên key.
Widget _wrap(
  GameSessionController session, {
  bool showForSystemPause = false,
  Locale locale = AppTranslations.fallback,
}) => GetMaterialApp(
  translations: AppTranslations(),
  locale: locale,
  home: Material(
    child: Stack(
      children: [
        const Center(child: Text('game content')),
        PauseOverlay(session: session, showForSystemPause: showForSystemPause),
      ],
    ),
  ),
);

GameSessionController _playingSession() => GameSessionController()
  ..markReady()
  ..start();

void main() {
  testWidgets('không hiện khi session đang playing', (tester) async {
    final session = _playingSession();
    await tester.pumpWidget(_wrap(session));
    await tester.pumpAndSettle();

    expect(find.text('Paused'), findsNothing);
  });

  testWidgets('hiện khi user pause', (tester) async {
    final session = _playingSession()..pause(GamePauseReason.user);
    await tester.pumpWidget(_wrap(session));
    await tester.pumpAndSettle();

    expect(find.text('Paused'), findsOneWidget);
    expect(_button('Resume'), findsWidgets);
    expect(_button('Restart'), findsWidgets);
  });

  testWidgets(
    'không tự hiện khi chỉ system pause và showForSystemPause=false (mặc định)',
    (tester) async {
      final session = _playingSession()..pause(GamePauseReason.system);
      await tester.pumpWidget(_wrap(session));
      await tester.pumpAndSettle();

      expect(find.text('Paused'), findsNothing);
    },
  );

  testWidgets('hiện cho system pause khi showForSystemPause=true', (
    tester,
  ) async {
    final session = _playingSession()..pause(GamePauseReason.system);
    await tester.pumpWidget(_wrap(session, showForSystemPause: true));
    await tester.pumpAndSettle();

    expect(find.text('Paused'), findsOneWidget);
  });

  testWidgets('bấm Resume gọi session.resume(user) đúng 1 lần', (tester) async {
    final session = _playingSession()..pause(GamePauseReason.user);
    await tester.pumpWidget(_wrap(session));
    await tester.pumpAndSettle();

    await tester.tap(_button('Resume').first);
    await tester.pumpAndSettle();

    expect(session.snapshot.value.phase, GameSessionPhase.playing);
    expect(find.text('Paused'), findsNothing);
  });

  testWidgets(
    'BUG-92: chỉ system pause + showForSystemPause=true, Resume gỡ system',
    (tester) async {
      final session = _playingSession()..pause(GamePauseReason.system);
      await tester.pumpWidget(_wrap(session, showForSystemPause: true));
      await tester.pumpAndSettle();

      await tester.tap(_button('Resume').first);
      await tester.pumpAndSettle();

      expect(session.snapshot.value.phase, GameSessionPhase.playing);
      expect(session.snapshot.value.pauseReasons, isEmpty);
      expect(find.text('Paused'), findsNothing);
    },
  );

  testWidgets(
    'BUG-92: cả system + user pause, Resume ưu tiên gỡ system nhưng không '
    'resume sớm khi user vẫn active',
    (tester) async {
      final session = _playingSession()
        ..pause(GamePauseReason.user)
        ..pause(GamePauseReason.system);
      await tester.pumpWidget(_wrap(session, showForSystemPause: true));
      await tester.pumpAndSettle();

      await tester.tap(_button('Resume').first);
      await tester.pumpAndSettle();

      expect(session.snapshot.value.phase, GameSessionPhase.paused);
      expect(session.snapshot.value.pauseReasons, {GamePauseReason.user});
      expect(find.text('Paused'), findsOneWidget);
    },
  );

  testWidgets(
    'IDEA-71/BUG-92: showForSystemPause=false + cả user lẫn system đang '
    'pause cùng lúc — back button CHỈ gỡ user, không đụng system (overlay '
    'này không quản lý system pause khi showForSystemPause tắt)',
    (tester) async {
      final session = _playingSession()
        ..pause(GamePauseReason.system)
        ..pause(GamePauseReason.user);
      await tester.pumpWidget(_wrap(session));
      await tester.pumpAndSettle();
      expect(find.text('Paused'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(session.snapshot.value.phase, GameSessionPhase.paused);
      expect(session.snapshot.value.pauseReasons, {GamePauseReason.system});
      // Overlay correctly hides itself now (only `system` remains, and this
      // instance is configured `showForSystemPause: false`).
      expect(find.text('Paused'), findsNothing);
    },
  );

  testWidgets('bấm Restart mặc định gọi session.restart()', (tester) async {
    final session = _playingSession()..pause(GamePauseReason.user);
    await tester.pumpWidget(_wrap(session));
    await tester.pumpAndSettle();

    await tester.tap(_button('Restart').first);
    await tester.pumpAndSettle();

    expect(session.snapshot.value.phase, GameSessionPhase.loading);
  });

  testWidgets('onResume/onRestart override thay hành vi mặc định', (
    tester,
  ) async {
    final session = _playingSession()..pause(GamePauseReason.user);
    var resumed = false;
    var restarted = false;
    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        home: Material(
          child: Stack(
            children: [
              PauseOverlay(
                session: session,
                onResume: () => resumed = true,
                onRestart: () => restarted = true,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(_button('Resume').first);
    await tester.pump();
    expect(resumed, isTrue);
    expect(
      session.snapshot.value.phase,
      GameSessionPhase.paused,
    ); // override, KHÔNG tự resume

    await tester.tap(_button('Restart').first);
    await tester.pump();
    expect(restarted, isTrue);
  });

  testWidgets('Settings/Quit ẩn khi không truyền callback, hiện khi có', (
    tester,
  ) async {
    final session = _playingSession()..pause(GamePauseReason.user);
    await tester.pumpWidget(_wrap(session));
    await tester.pumpAndSettle();
    expect(_button('Settings'), findsNothing);
    expect(_button('Quit'), findsNothing);

    var quit = false;
    var settings = false;
    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        home: Material(
          child: Stack(
            children: [
              PauseOverlay(
                session: session,
                onSettings: () => settings = true,
                onQuit: () => quit = true,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(_button('Settings'), findsWidgets);
    expect(_button('Quit'), findsWidgets);

    await tester.tap(_button('Settings').first);
    await tester.pump();
    expect(settings, isTrue);

    await tester.tap(_button('Quit').first);
    await tester.pump();
    expect(quit, isTrue);
  });

  testWidgets('back button lúc overlay hiện thì resume, không pop route', (
    tester,
  ) async {
    final session = _playingSession()..pause(GamePauseReason.user);
    await tester.pumpWidget(_wrap(session));
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(session.snapshot.value.phase, GameSessionPhase.playing);
    expect(
      find.text('game content'),
      findsOneWidget,
    ); // route vẫn còn, không bị pop
  });

  testWidgets(
    'back button lúc overlay ẩn: không làm gì đặc biệt (canPop giữ nguyên)',
    (tester) async {
      final session = _playingSession();
      await tester.pumpWidget(_wrap(session));
      await tester.pumpAndSettle();

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'reduced motion: dùng AnimatedSwitcher/AnimatedOpacity duration 0',
    (tester) async {
      final session = _playingSession()..pause(GamePauseReason.user);
      await tester.pumpWidget(
        GetMaterialApp(
          translations: AppTranslations(),
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Material(
              child: Stack(children: [PauseOverlay(session: session)]),
            ),
          ),
        ),
      );
      await tester.pump();

      final switcher = tester.widget<AnimatedSwitcher>(
        find.byType(AnimatedSwitcher),
      );
      expect(switcher.duration, Duration.zero);
    },
  );

  testWidgets('RTL + text scale lớn không throw', (tester) async {
    final session = _playingSession()..pause(GamePauseReason.user);
    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
            child: Material(
              child: Stack(children: [PauseOverlay(session: session)]),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  group('FEAT-82: focus trap/release qua đúng modal lifecycle', () {
    testWidgets(
      'pause khi 1 nút game đang focus -> panel giành focus; resume -> focus trả lại đúng nút đó',
      (tester) async {
        final session = _playingSession();
        final gameButtonFocus = FocusNode(debugLabel: 'gameButton');
        await tester.pumpWidget(
          GetMaterialApp(
            translations: AppTranslations(),
            home: Material(
              child: Stack(
                children: [
                  Center(
                    child: ElevatedButton(
                      focusNode: gameButtonFocus,
                      onPressed: () {},
                      child: const Text('game action'),
                    ),
                  ),
                  PauseOverlay(session: session),
                ],
              ),
            ),
          ),
        );

        gameButtonFocus.requestFocus();
        await tester.pump();
        expect(gameButtonFocus.hasFocus, isTrue);

        session.pause(GamePauseReason.user);
        await tester.pumpAndSettle();

        expect(gameButtonFocus.hasFocus, isFalse);

        await tester.tap(_button('Resume').first);
        await tester.pumpAndSettle();
        await tester.pump();

        expect(gameButtonFocus.hasFocus, isTrue);
        gameButtonFocus.dispose();
      },
    );
  });

  group('BUG-94: i18n sweep', () {
    testWidgets('locale vi: default title/resume/restart/quit dịch đúng', (
      tester,
    ) async {
      final session = GameSessionController()
        ..markReady()
        ..start()
        ..pause(GamePauseReason.user);
      await tester.pumpWidget(
        GetMaterialApp(
          translations: AppTranslations(),
          locale: const Locale('vi'),
          home: Material(
            child: Stack(
              children: [
                const Center(child: Text('game content')),
                PauseOverlay(session: session, onQuit: () {}),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Đã tạm dừng'), findsOneWidget);
      expect(_button('Tiếp tục'), findsWidgets);
      expect(_button('Chơi lại'), findsWidgets);
      expect(_button('Thoát'), findsWidgets);
    });

    testWidgets(
      'custom label override vẫn giữ nguyên, không bị .tr đè (en lẫn vi)',
      (tester) async {
        final session = GameSessionController()
          ..markReady()
          ..start()
          ..pause(GamePauseReason.user);
        await tester.pumpWidget(
          GetMaterialApp(
            translations: AppTranslations(),
            locale: const Locale('vi'),
            home: Material(
              child: Stack(
                children: [
                  PauseOverlay(
                    session: session,
                    title: 'Custom Title',
                    resumeLabel: 'Custom Resume',
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('Custom Title'), findsOneWidget);
        expect(_button('Custom Resume'), findsWidgets);
      },
    );
  });
}
