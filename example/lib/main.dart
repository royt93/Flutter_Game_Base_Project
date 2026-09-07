import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'package:roy_casual_kit/core/app_info.dart';
import 'package:roy_casual_kit/core/app_translations.dart';
import 'package:roy_casual_kit/core/audio_manager.dart';
import 'package:roy_casual_kit/core/crash_reporter.dart';
import 'package:roy_casual_kit/core/debug_log.dart';
import 'package:roy_casual_kit/core/locale_service.dart';
import 'package:roy_casual_kit/core/neon_theme.dart';
import 'package:roy_casual_kit/core/reminder_service.dart';
import 'package:roy_casual_kit/core/runtime_flags.dart';
import 'package:roy_casual_kit/core/storage_service.dart';

import 'screens/home_screen.dart';

void main() => runZonedGuarded(() => app(), reportUncaughtError);

/// Shared sink for every runtime error this app can catch — the
/// `runZonedGuarded` zone error callback below (async errors: timers,
/// stream listeners, unawaited futures) AND `FlutterError.onError` (framework
/// build/layout/paint errors), set inside [app]. Forwards to
/// `CrashReporter.maybe` so nothing is silent in a release build (`dlog()`
/// itself no-ops there). No-op if the consuming app hasn't registered a
/// `CrashReporter` implementation.
void reportUncaughtError(Object error, StackTrace stack) {
  CrashReporter.maybe?.recordError(error, stack);
}

/// Overrides `FlutterError.onError` to forward framework (build/layout/
/// paint) errors into [reportUncaughtError] too, chaining to whatever
/// handler was already set (test bindings install their own). Split out
/// from [app] so it's testable without that function's platform-channel-
/// heavy init (SharedPreferences, PackageInfo, Wakelock — none of which
/// have real handlers in a plain `flutter test`, only on a real device/
/// integration_test).
void installErrorHandlers() {
  final previousOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    reportUncaughtError(details.exception, details.stack ?? StackTrace.empty);
    (previousOnError ?? FlutterError.presentError)(details);
  };
}

/// Điểm khởi chạy app (tách riêng để integration_test gọi lại được).
/// [withAudio] mặc định `!isE2eTest`: audioplayers đăng ký frame callback
/// liên tục, gây lỗi "animation still running" lúc teardown trong device
/// test tự động (`--dart-define=E2E_TEST=true`) — vẫn có thể override thủ
/// công khi gọi `app()` trực tiếp.
Future<void> app({bool withAudio = !isE2eTest}) async {
  dlog('app: ensureInitialized');
  WidgetsFlutterBinding.ensureInitialized();
  installErrorHandlers();
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
  Get.put(ReminderService(), permanent: true);
  // GetMaterialApp's `locale:` param chỉ áp dụng lúc build lần đầu; nếu
  // `app()` từng chạy trước đó trong cùng process (vd test gọi lại), GetX
  // vẫn giữ `Get.locale` cũ nên phải chủ động set lại ở đây, không thể chỉ
  // dựa vào tham số constructor.
  Get.updateLocale(locale.current.value);

  if (withAudio) {
    Get.put(AudioManager(), permanent: true);
  }

  runApp(RoyBaseGameApp(initialLocale: locale.current.value));
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

/// Khởi tạo SharedPreferences; thiết bị hiếm với storage lỗi không được làm
/// app crash trắng màn hình — trả null để [StorageService] tự dùng fallback
/// in-memory.
Future<SharedPreferences?> _loadPrefs() async {
  try {
    return await SharedPreferences.getInstance();
  } catch (e) {
    dlog('SharedPreferences init failed, dùng in-memory fallback: $e');
    return null;
  }
}

bool _appVersionLoaded = false;

/// Nạp version thật từ pubspec (qua package_info_plus) vào [kAppVersion].
/// Lỗi (vd nền tảng test) → giữ nguyên fallback. Chỉ gọi platform channel 1
/// lần cho cả tiến trình — version không đổi trong lúc app đang chạy, nên
/// [_appVersionLoaded] chặn gọi lại nếu `app()` từng chạy nhiều lần trong
/// cùng process (vd test).
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

class RoyBaseGameApp extends StatefulWidget {
  final Locale initialLocale;

  const RoyBaseGameApp({super.key, required this.initialLocale});

  @override
  State<RoyBaseGameApp> createState() => _RoyBaseGameAppState();
}

class _RoyBaseGameAppState extends State<RoyBaseGameApp>
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
      title: 'Roy Casual Kit Example',
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
