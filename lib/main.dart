import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/app_translations.dart';
import 'core/audio_manager.dart';
import 'core/locale_service.dart';
import 'core/neon_theme.dart';
import 'core/storage_service.dart';
import 'presentation/screens/home_screen.dart';

void main() => app();

/// Điểm khởi chạy app (tách riêng để integration_test gọi lại được).
Future<void> app() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Full screen: ẩn status bar + navigation bar.
  // Dùng `manual` + overlays rỗng thay vì immersiveSticky để KHÔNG reserve
  // vùng cử chỉ mép trên (vốn nuốt tap nút X ở HUD).
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: []);
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  final prefs = await SharedPreferences.getInstance();
  final store = Get.put(StorageService(prefs), permanent: true);
  final locale = Get.put(LocaleService(store), permanent: true);

  final audio = Get.put(AudioManager(), permanent: true);
  audio.init().then((_) => audio.startBgm());

  runApp(NeonJewelsApp(initialLocale: locale.current.value));
}

class NeonJewelsApp extends StatelessWidget {
  final Locale initialLocale;
  const NeonJewelsApp({super.key, required this.initialLocale});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Neon Jewels',
      debugShowCheckedModeBanner: false,
      translations: AppTranslations(),
      locale: initialLocale,
      fallbackLocale: AppTranslations.fallback,
      supportedLocales: AppTranslations.supported,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: NeonTheme.bgDark,
        colorScheme: const ColorScheme.dark(
          primary: NeonTheme.cyan,
          secondary: NeonTheme.magenta,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
