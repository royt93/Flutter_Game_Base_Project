/// App info (shown on Home / About).
const String kAppName = 'Roy Project Base Game';
const String kCopyright = '© SAIGON PHANTOM LABS';

/// Displayed version + build number — read AUTOMATICALLY from pubspec at
/// startup (see `loadAppVersion` in `main.dart`), so it never drifts from
/// `pubspec.yaml`. The default value is only a fallback for when
/// package_info hasn't loaded yet (e.g. widget tests).
String kAppVersion = '2026.06.15';
String kAppBuildNumber = '20260615';

/// Package/bundle id — read AUTOMATICALLY from `loadAppVersion` just like
/// [kAppVersion], used for store links (rate/share) instead of a hardcoded
/// string.
String kPackageName = 'com.galaxyjoy.roybasegame';
