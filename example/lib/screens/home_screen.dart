import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:roy_casual_kit/core/neon_theme.dart';
import 'package:roy_casual_kit/presentation/widgets/neon_bg.dart';
import 'package:roy_casual_kit/presentation/widgets/neon_button.dart';
import 'package:roy_casual_kit/presentation/widgets/stroke_text.dart';

import 'settings_screen.dart';
import 'widget_showcase_screen.dart';

/// Minimal home screen: base-project placeholder, one entry to Settings.
/// Extend per-project (add your own cards/actions) rather than growing this.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NeonBg(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const StrokeText('Roy Project Base Game', fontSize: 28),
              const SizedBox(height: 24),
              NeonButton(
                label: 'settings'.tr,
                color: NeonTheme.cyan,
                onTap: () => Get.to(() => const SettingsScreen()),
              ),
              const SizedBox(height: 16),
              NeonButton(
                label: 'widget_showcase'.tr,
                color: NeonTheme.magenta,
                onTap: () => Get.to(() => const WidgetShowcaseScreen()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
