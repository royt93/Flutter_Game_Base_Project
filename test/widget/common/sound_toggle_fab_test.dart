import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/core/audio_manager.dart';
import 'package:roy_casual_kit/core/storage_service.dart';
import 'package:roy_casual_kit/presentation/widgets/common/sound_toggle_fab.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  tearDown(Get.reset);

  group('AudioManager registered', () {
    testWidgets('tap toggles muted and flips the icon', (tester) async {
      // toggleMute() persists via StorageService.to, so it must be
      // registered too (see audio_manager_test.dart's setUp).
      SharedPreferences.setMockInitialValues({});
      Get.put(StorageService(await SharedPreferences.getInstance()));
      final audio = Get.put(AudioManager(), permanent: true);
      expect(audio.muted.value, isFalse);

      await tester.pumpWidget(
        const MaterialApp(home: Material(child: SoundToggleFab())),
      );

      expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
      expect(find.byIcon(Icons.volume_off_rounded), findsNothing);

      await tester.tap(find.byType(SoundToggleFab));
      await tester.pump();

      expect(audio.muted.value, isTrue);
      expect(find.byIcon(Icons.volume_off_rounded), findsOneWidget);
      expect(find.byIcon(Icons.volume_up_rounded), findsNothing);

      // Tap again toggles back.
      await tester.tap(find.byType(SoundToggleFab));
      await tester.pump();

      expect(audio.muted.value, isFalse);
      expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('AudioManager not registered', () {
    testWidgets('renders nothing, does not throw', (tester) async {
      expect(Get.isRegistered<AudioManager>(), isFalse);

      await tester.pumpWidget(
        const MaterialApp(home: Material(child: SoundToggleFab())),
      );

      expect(find.byType(SoundToggleFab), findsOneWidget);
      expect(find.byIcon(Icons.volume_up_rounded), findsNothing);
      expect(find.byIcon(Icons.volume_off_rounded), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
