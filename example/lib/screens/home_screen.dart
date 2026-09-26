import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:roy_casual_kit/roy_casual_kit.dart';

import 'cookbook_screen.dart';
import 'daily_reward_screen.dart';
import 'game_demo_screen.dart';
import 'save_cloud_screen.dart';
import 'settings_screen.dart';
import 'shop_screen.dart';
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const StrokeText('Roy Casual Kit Example', fontSize: 28),
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
                const SizedBox(height: 16),
                NeonButton(
                  label: 'game_demo'.tr,
                  color: NeonTheme.orange,
                  onTap: () => Get.to(() => const GameDemoScreen()),
                ),
                const SizedBox(height: 16),
                NeonButton(
                  label: 'daily_rewards'.tr,
                  color: NeonTheme.gold,
                  onTap: () => Get.to(() => const DailyRewardScreen()),
                ),
                const SizedBox(height: 16),
                NeonButton(
                  label: 'shop'.tr,
                  color: NeonTheme.lime,
                  onTap: () => Get.to(() => const ShopScreen()),
                ),
                const SizedBox(height: 16),
                NeonButton(
                  label: 'save_cloud'.tr,
                  color: NeonTheme.blue,
                  onTap: () => Get.to(() => const SaveCloudScreen()),
                ),
                const SizedBox(height: 16),
                NeonButton(
                  label: 'cookbook'.tr,
                  color: NeonTheme.purple,
                  onTap: () => Get.to(() => const CookbookScreen()),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
