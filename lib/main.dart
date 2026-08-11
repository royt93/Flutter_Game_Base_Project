import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'core/app_info.dart';
import 'core/app_translations.dart';
import 'core/audio_manager.dart';
import 'core/debug_log.dart';
import 'core/locale_service.dart';
import 'core/neon_theme.dart';
import 'core/reminder_service.dart';
import 'core/storage_service.dart';
import 'core/runtime_flags.dart';
import 'presentation/controllers/game_controller.dart';
import 'presentation/screens/home_screen.dart';

void main() => app();

/// Điểm khởi chạy app (tách riêng để integration_test gọi lại được).
/// [withAudio] = false trong integration test: audioplayers đăng ký frame
/// callback liên tục, gây lỗi "animation still running" lúc teardown.
Future<void> app({bool withAudio = true}) async {
  dlog('app: ensureInitialized');
  WidgetsFlutterBinding.ensureInitialized();
  // Full screen: ẩn status bar + navigation bar.
  // Dùng `manual` + overlays rỗng thay vì immersiveSticky để KHÔNG reserve
  // vùng cử chỉ mép trên (vốn nuốt tap nút X ở HUD).
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: []);
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  // Giữ màn hình sáng suốt vòng đời app, không chỉ lúc chơi.
  WakelockPlus.enable();

  dlog('app: loadAppVersion start');
  await loadAppVersion();
  dlog('app: loadAppVersion done');

  dlog('app: prefs start');
  final store = Get.put(StorageService(await _loadPrefs()), permanent: true);
  dlog('app: prefs done');
  NeonTheme.dark = store.getBool(StorageKeys.themeDark);
  final locale = Get.put(LocaleService(store), permanent: true);
  // GameController phải đăng ký TRƯỚC updateLocale(): updateLocale() gọi
  // engine.performReassemble() (rebuild toàn bộ element tree kể cả widget
  // offstage), nên nếu HomeScreen build lại trước khi GameController tồn
  // tại → "GameController not found". Get.put() đồng bộ nên chỉ cần đổi
  // thứ tự là đóng được race window này.
  Get.put(GameController(), permanent: true);
  Get.put(ReminderService(), permanent: true);
  // GetMaterialApp's `locale:` param chỉ áp dụng lúc build lần đầu. Khi
  // restartApp() gọi lại app() trong cùng process, GetX vẫn giữ Get.locale
  // cũ (từ lần đổi ngôn ngữ trước) nên phải chủ động set lại ở đây, không
  // thể chỉ dựa vào tham số constructor.
  Get.updateLocale(locale.current.value);

  if (withAudio) {
    Get.put(AudioManager(), permanent: true);
  }

  runApp(PopStarBlastApp(initialLocale: locale.current.value));
  dlog('app: runApp done');

  // Sau first frame: tránh I/O contention với Flame init → giảm startup jank.
  if (withAudio) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AudioManager.maybe?.init().then((_) => AudioManager.maybe?.startBgm());
    });
  }
  // I56: lên lịch lại reminder mỗi lần app mở (mọi lỗi permission/plugin bị
  // nuốt bên trong scheduleNext(), không cần gate theo withAudio).
  WidgetsBinding.instance.addPostFrameCallback((_) {
    ReminderService.maybe?.scheduleNext();
  });
}

/// Xoá mọi singleton GetX rồi chạy lại [app()] — dùng sau import backup để
/// mọi controller đọc lại state mới từ storage, khỏi phải tự reload từng
/// cái (dễ sót khi thêm service mới).
Future<void> restartApp() async {
  Get.deleteAll(force: true);
  // Integration tests start without audio because its frame callbacks can
  // keep the test binding alive during teardown. Production keeps audio.
  await app(withAudio: !isE2eTest);
  // runApp preserves the existing Navigator when the root widget type is the
  // same. Reset the route stack so restore never leaves a stale Settings
  // route or dialog on screen.
  Get.offAll(() => const HomeScreen());
}

/// Khởi tạo SharedPreferences; thiết bị hiếm với storage lỗi không được làm
/// app crash trắng màn hình — trả null để [StorageService] tự dùng fallback
/// in-memory.
Future<SharedPreferences?> _loadPrefs() async {
  try {
    return await SharedPreferences.getInstance();
  } catch (e) {
    dlog('roy93~ SharedPreferences init failed, dùng in-memory fallback: $e');
    return null;
  }
}

bool _appVersionLoaded = false;

/// Nạp version thật từ pubspec (qua package_info_plus) vào [kAppVersion].
/// Lỗi (vd nền tảng test) → giữ nguyên fallback. Chỉ gọi platform channel 1
/// lần cho cả tiến trình — `restartApp()` gọi lại `app()` mỗi lần import
/// backup, không cần hỏi lại `PackageInfo.fromPlatform()` vì version không
/// đổi trong lúc app đang chạy.
Future<void> loadAppVersion() async {
  if (_appVersionLoaded) return;
  try {
    final info = await PackageInfo.fromPlatform();
    if (info.version.isNotEmpty) kAppVersion = info.version;
    if (info.buildNumber.isNotEmpty) kAppBuildNumber = info.buildNumber;
    if (info.packageName.isNotEmpty) kPackageName = info.packageName;
    _appVersionLoaded = true;
  } catch (_) {
    // giữ fallback trong app_info.dart, thử lại ở lần app() kế tiếp
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
    if (state == AppLifecycleState.resumed) {
      audio?.resumeBgm();
    } else {
      // paused / inactive / hidden / detached → dừng nhạc
      audio?.pauseBgm();
      // X24: đây là mốc cuối cùng chắc chắn còn chạy trước khi OS có thể giết
      // process — đẩy nốt counter đang đệm (xem [StorageService.flush]).
      // Không await: `didChangeAppLifecycleState` là sync, và SharedPreferences
      // ghi vào bộ nhớ trước rồi mới xuống đĩa nên giá trị không mất.
      StorageService.maybe?.flush();
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
            colorScheme: ColorScheme.light(
              primary: NeonTheme.purple,
              secondary: NeonTheme.magenta,
              surface: NeonTheme.card,
              onSurface: NeonTheme.ink,
            ),
            // ponytail: SwitchListTile chỉ set màu active per-instance, state
            // OFF rơi về Switch mặc định (đen/trắng) — lệch theme candy-neon.
            // Set track/thumb OFF ở đây 1 lần cho mọi Switch trong app. Dùng
            // `ink` (đậm) thay vì `inkSoft` alpha thấp — bản cũ gần như vô
            // hình trên nền pastel sáng (candy bg).
            switchTheme: SwitchThemeData(
              trackColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? null
                    : NeonTheme.ink.withValues(alpha: 0.28),
              ),
              trackOutlineColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? null
                    : NeonTheme.ink.withValues(alpha: 0.45),
              ),
              thumbColor: WidgetStateProperty.resolveWith(
                (states) =>
                    states.contains(WidgetState.selected) ? null : Colors.white,
              ),
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
