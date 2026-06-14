import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
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
/// [withAudio] = false trong integration test: audioplayers đăng ký frame
/// callback liên tục, gây lỗi "animation still running" lúc teardown.
Future<void> app({bool withAudio = true}) async {
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

  if (withAudio) {
    final audio = Get.put(AudioManager(), permanent: true);
    audio.init().then((_) => audio.startBgm());
  }

  runApp(NeonJewelsApp(initialLocale: locale.current.value));
}

class NeonJewelsApp extends StatefulWidget {
  final Locale initialLocale;
  const NeonJewelsApp({super.key, required this.initialLocale});

  @override
  State<NeonJewelsApp> createState() => _NeonJewelsAppState();
}

class _NeonJewelsAppState extends State<NeonJewelsApp>
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
      title: 'Neon Jewels',
      debugShowCheckedModeBanner: false,
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
