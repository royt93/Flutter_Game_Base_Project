import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/app_info.dart';
import 'core/app_translations.dart';
import 'core/audio_manager.dart';
import 'core/locale_service.dart';
import 'core/neon_theme.dart';
import 'core/storage_service.dart';
import 'presentation/controllers/game_controller.dart';
import 'presentation/screens/home_screen.dart';

void main() => app();

/// Điểm khởi chạy app (tách riêng để integration_test gọi lại được).
/// [withAudio] = false trong integration test: audioplayers đăng ký frame
/// callback liên tục, gây lỗi "animation still running" lúc teardown.
Future<void> app({bool withAudio = true}) async {
  WidgetsFlutterBinding.ensureInitialized();
  // Full screen: ẩn status bar + navigation bar.
  // Dùng `manual` + overlays rỗng thay vì immersiveSticky để KHÔNG reserve
  // vùng cử chỉ mép trên (vốn nuốt tap nút X ở HUD).
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: []);
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  await loadAppVersion();

  final prefs = await SharedPreferences.getInstance();
  final store = Get.put(StorageService(prefs), permanent: true);
  final locale = Get.put(LocaleService(store), permanent: true);
  Get.put(GameController(), permanent: true);

  if (withAudio) {
    Get.put(AudioManager(), permanent: true);
  }

  runApp(PopStarBlastApp(initialLocale: locale.current.value));

  // Sau first frame: tránh I/O contention với Flame init → giảm startup jank.
  if (withAudio) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AudioManager.maybe?.init().then((_) => AudioManager.maybe?.startBgm());
    });
  }
}

/// Nạp version thật từ pubspec (qua package_info_plus) vào [kAppVersion].
/// Lỗi (vd nền tảng test) → giữ nguyên fallback.
Future<void> loadAppVersion() async {
  try {
    final info = await PackageInfo.fromPlatform();
    if (info.version.isNotEmpty) kAppVersion = info.version;
  } catch (_) {
    // giữ fallback trong app_info.dart
  }
}

class PopStarBlastApp extends StatefulWidget {
  final Locale initialLocale;

  const PopStarBlastApp({super.key, required this.initialLocale});

  @override
  State<PopStarBlastApp> createState() => _PopStarBlastAppState();
}

class _PopStarBlastAppState extends State<PopStarBlastApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Tạm dừng nhạc khi app ra background, phát lại khi quay vào.
  // Trước đây thiếu observer này nên nhạc vẫn chạy khi back ra launcher.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final audio = AudioManager.maybe;
    if (audio == null) return;
    if (state == AppLifecycleState.resumed) {
      audio.resumeBgm();
    } else {
      // paused / inactive / hidden / detached → dừng nhạc
      audio.pauseBgm();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Pop Star Blast',
      debugShowCheckedModeBanner: false,
      defaultTransition: Transition.cupertino,
      transitionDuration: const Duration(milliseconds: 280),
      translations: AppTranslations(),
      locale: widget.initialLocale,
      fallbackLocale: AppTranslations.fallback,
      supportedLocales: AppTranslations.supported,
      // Material/Cupertino localizations cho mọi ngôn ngữ (tooltip, ngày giờ,
      // semantics…) — nếu thiếu sẽ ném lỗi với locale ngoài en.
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme:
          ThemeData(
            useMaterial3: true,
            fontFamily: NeonTheme.fontFamily, // Baloo2 mặc định toàn app
            scaffoldBackgroundColor: NeonTheme.bgMid,
            colorScheme: const ColorScheme.light(
              primary: NeonTheme.purple,
              secondary: NeonTheme.magenta,
              surface: NeonTheme.card,
              onSurface: NeonTheme.ink,
            ),
            // ponytail: Baloo2 thiếu vài glyph Cyrillic hiếm (ví dụ "ї" trong
            // "Українська") → fallback sang font hệ thống Android khi thiếu.
          ).copyWith(
            textTheme: ThemeData(
              fontFamily: NeonTheme.fontFamily,
            ).textTheme.apply(fontFamilyFallback: const ['sans-serif']),
          ),
      home: const HomeScreen(),
    );
  }
}
