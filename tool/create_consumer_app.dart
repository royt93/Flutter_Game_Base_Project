// Consumer App Starter Generator (FEAT-73) — scaffolds a brand-new
// Flutter app wired to `roy_casual_kit`: `RoyCasualKit.initialize`
// bootstrap, a Flame demo screen, a small widget showcase screen, a smoke
// test, and a GitHub Actions CI workflow.
//
// Usage:
//   dart run tool/create_consumer_app.dart --name=my_game [--output=.]
//     [--org=com.example] [--kitVersion=^0.2.0] [--kitPath=<path>] [--force]
//   dart run tool/create_consumer_app.dart --check-version=<app_dir>
//
// Shells out to the REAL `flutter create` for the platform scaffolding
// (android/ios/pubspec.yaml/analysis_options.yaml) — reimplementing that
// would be fragile and duplicate work the Flutter SDK already does
// correctly — then overlays this package's own template files on top and
// patches `pubspec.yaml` to depend on `roy_casual_kit`.
//
// **Non-interactive safety**: refuses to touch a target directory that
// already exists and is non-empty unless `--force` is passed — a
// generator's job is creating NEW apps; re-running it against an
// existing one to *upgrade* a template is a different, unimplemented
// feature (see `--check-version` below for the read-only first step
// toward that).
import 'dart:io';

/// Bump when any template file's *content* changes in a way an existing
/// generated app should know about — `--check-version` compares against
/// this. Actually re-applying a newer template onto an existing app
/// (auto-migration) is intentionally NOT implemented by this task — see
/// this task's Quyết định for why that's a deliberately separate, larger
/// feature.
const int templateSchemaVersion = 1;

const _templateVersionFileName = '.roy_template_version';

const _dartReservedWords = {
  'assert', 'break', 'case', 'catch', 'class', 'const', 'continue',
  'default', 'do', 'else', 'enum', 'extends', 'false', 'final', 'finally',
  'for', 'if', 'in', 'is', 'new', 'null', 'rethrow', 'return', 'super',
  'switch', 'this', 'throw', 'true', 'try', 'var', 'void', 'while', 'with',
  'import', 'library', 'part', 'typedef', 'yield', 'async', 'await',
};

/// A valid Flutter/Dart package name: lowercase snake_case, must start
/// with a letter, not a Dart reserved word — same rule `flutter create`
/// itself enforces, checked here too so a bad name fails fast with a
/// clear message instead of `flutter create`'s own (less kit-specific)
/// error text.
bool isValidAppName(String name) {
  if (name.isEmpty || name.length > 64) return false;
  if (!RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(name)) return false;
  return !_dartReservedWords.contains(name);
}

/// A valid reverse-domain org id (`com.example`, `com.example.studio`) —
/// at least 2 dot-separated segments, each starting with a letter.
bool isValidOrg(String org) {
  final segments = org.split('.');
  if (segments.length < 2) return false;
  return segments.every((s) => RegExp(r'^[a-zA-Z][a-zA-Z0-9]*$').hasMatch(s));
}

/// The dependency block to insert into the generated app's
/// `pubspec.yaml` — `roy_casual_kit` (a `path:` dependency when
/// [kitPath] is given, for this generator's own test suite to point back
/// at THIS repo without needing it published; otherwise a normal pub.dev
/// version constraint) PLUS `get`/`flame` as explicit direct
/// dependencies.
///
/// `get`/`flame`/`shared_preferences` are only *transitive* dependencies
/// once `roy_casual_kit` is added — resolvable and usable at runtime
/// either way — but `flutter_lints`' default
/// `depend_on_referenced_packages` rule (part of `flutter create`'s own
/// generated `analysis_options.yaml`) flags importing a package that
/// isn't a *direct* dependency, which would otherwise make `flutter
/// analyze` report issues immediately after generation — failing this
/// task's own "output analyze sạch ngay sau generate" acceptance
/// criterion (found by actually running the generated app's `flutter
/// analyze`, twice — once for `lib/`'s `get`/`flame` imports, again for
/// the generated smoke test's `shared_preferences` import). Versions
/// pinned to match this package's own `pubspec.yaml` so both resolve the
/// same package graph.
String kitDependencyBlock({String? kitPath, String kitVersion = '^0.2.0'}) {
  final kitLine = kitPath != null
      ? '  roy_casual_kit:\n    path: $kitPath\n'
      : '  roy_casual_kit: $kitVersion\n';
  return '$kitLine  get: ^4.7.3\n  flame: ^1.35.1\n  shared_preferences: ^2.5.5\n';
}

/// Inserts [dependencyBlock] right after the first `dependencies:` line
/// in [pubspecContent]. Throws [ArgumentError] if no such line exists —
/// a `pubspec.yaml` `flutter create` itself produced always has one, so
/// this only trips if something upstream already went wrong.
String patchPubspecWithDependency(String pubspecContent, String dependencyBlock) {
  final lines = pubspecContent.split('\n');
  final index = lines.indexWhere((l) => l.trim() == 'dependencies:');
  if (index == -1) {
    throw ArgumentError('pubspec.yaml có không "dependencies:" line để chèn vào');
  }
  lines.insert(index + 1, dependencyBlock.trimRight());
  return lines.join('\n');
}

/// Enables Android core library desugaring in `flutter create`'s
/// generated `android/app/build.gradle.kts` and adds the
/// `coreLibraryDesugaring` dependency it needs — required because
/// `roy_casual_kit` depends on `flutter_local_notifications`
/// (`ReminderService`), which needs desugaring enabled REGARDLESS of
/// whether the generated app actually registers the `reminders`
/// bootstrap module. Without this, `flutter build apk` fails immediately
/// with `Dependency ':flutter_local_notifications' requires core library
/// desugaring to be enabled` — found by actually building the generated
/// app on a real device (see this task's Quyết định), not by reading
/// docs. Throws [ArgumentError] if [buildGradleContent] doesn't look like
/// `flutter create`'s own template (no `targetCompatibility` line to
/// anchor on).
String patchAndroidBuildGradleForDesugaring(String buildGradleContent) {
  final anchor = RegExp(r'( *)targetCompatibility = JavaVersion\.VERSION_\d+\n');
  final match = anchor.firstMatch(buildGradleContent);
  if (match == null) {
    throw ArgumentError(
      'build.gradle.kts không có dòng targetCompatibility để neo vào — '
      'định dạng flutter create có thể đã đổi.',
    );
  }
  final indent = match.group(1)!;
  final withDesugaring = buildGradleContent.replaceRange(
    match.end,
    match.end,
    '${indent}isCoreLibraryDesugaringEnabled = true\n',
  );
  return '$withDesugaring\n'
      'dependencies {\n'
      '    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n'
      '}\n';
}

String mainDartTemplate({required String appName}) {
  final className = '${_pascalCase(appName)}App';
  return '''
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/roy_casual_kit.dart';

import 'screens/home_screen.dart';

// Generated by roy_casual_kit's Consumer App Starter Generator (FEAT-73).
// Template schema version: $templateSchemaVersion — see
// .roy_template_version.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RoyCasualKit.initialize(
    config: const RoyCasualKitConfig(
      modules: {
        RoyCasualKitModule.storage,
        RoyCasualKitModule.locale,
        RoyCasualKitModule.lifecycle,
      },
    ),
  );
  runApp(const $className());
}

class $className extends StatelessWidget {
  const $className({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: '$appName',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(fontFamily: NeonTheme.fontFamily),
      home: const HomeScreen(),
    );
  }
}
''';
}

String _pascalCase(String snakeCase) => snakeCase
    .split('_')
    .where((s) => s.isNotEmpty)
    .map((s) => s[0].toUpperCase() + s.substring(1))
    .join();

String homeScreenTemplate() => '''
import 'package:flutter/material.dart';

import 'widget_showcase_screen.dart';
import 'game_demo_screen.dart';

/// Generated starter home screen — 2 entry points proving the kit's 2
/// main integration surfaces (a plain widget screen, a Flame game
/// screen) both work out of the box. Replace with your own game's home
/// screen; this one exists so `flutter test`/a device smoke test has
/// something real to exercise right after generation.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              key: const Key('open_widget_showcase'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const WidgetShowcaseScreen()),
              ),
              child: const Text('Widget Showcase'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              key: const Key('open_game_demo'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const GameDemoScreen()),
              ),
              child: const Text('Game Demo'),
            ),
          ],
        ),
      ),
    );
  }
}
''';

String widgetShowcaseScreenTemplate() => '''
import 'package:flutter/material.dart';
import 'package:roy_casual_kit/roy_casual_kit.dart';

/// A minimal starting point — NOT a copy of roy_casual_kit's own internal
/// `example/` app (that one demos all ~47 common widgets for the kit's
/// own test coverage; a generated app doesn't need that much surface).
/// Add your own game's widgets here as you build them.
class WidgetShowcaseScreen extends StatelessWidget {
  const WidgetShowcaseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Widget Showcase')),
      body: Center(
        child: CommonButton(label: 'Hello roy_casual_kit', onTap: () {}),
      ),
    );
  }
}
''';

String gameDemoScreenTemplate() => '''
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:roy_casual_kit/presentation/game/roy_game.dart';

/// Embeds the kit's minimal `RoyGame` `FlameGame` — replace with your
/// own `FlameGame` subclass as your project grows; this one exists to
/// prove the Flame/`GameWidget` wiring works right after generation.
class GameDemoScreen extends StatelessWidget {
  const GameDemoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Game Demo')),
      body: GameWidget(game: RoyGame()),
    );
  }
}
''';

String smokeTestTemplate({required String appName}) => '''
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:roy_casual_kit/roy_casual_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:$appName/screens/home_screen.dart';
import 'package:$appName/screens/widget_showcase_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() async {
    await RoyCasualKit.resetForTesting();
    Get.reset();
  });

  testWidgets('HomeScreen mở được Widget Showcase, không throw', (tester) async {
    // SharedPreferences.getInstance() phải được mock TRƯỚC — gọi thẳng nó
    // qua RoyCasualKitConfig.storage module (không truyền preferences) sẽ
    // treo vô thời hạn dưới flutter test (không có platform channel thật
    // trả lời), đúng bug này generator từng gặp khi build template — xem
    // test/core/kit_bootstrap_test.dart cho pattern gốc.
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await RoyCasualKit.initialize(
      config: RoyCasualKitConfig(
        modules: {RoyCasualKitModule.storage, RoyCasualKitModule.locale},
        preferences: prefs,
      ),
    );
    await tester.pumpWidget(const GetMaterialApp(home: HomeScreen()));

    await tester.tap(find.byKey(const Key('open_widget_showcase')));
    await tester.pumpAndSettle();

    expect(find.byType(WidgetShowcaseScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
''';

String ciWorkflowTemplate() => '''
name: CI

on:
  push:
    branches: [main]
  pull_request:

jobs:
  analyze-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          cache: true
      - run: flutter pub get
      - name: Analyze
        run: flutter analyze
      - name: Test
        run: flutter test
''';

class GeneratedApp {
  const GeneratedApp({required this.path, required this.writtenFiles});

  final String path;
  final List<String> writtenFiles;
}

/// Runs the full generator: `flutter create` for the platform skeleton,
/// then overlays this package's own template files, then patches
/// `pubspec.yaml`. Throws [ArgumentError] on an invalid [name]/[org],
/// [StateError] if the target directory exists and is non-empty and
/// [force] is `false`, or the underlying `flutter create` process's
/// stderr wrapped in a [StateError] if that fails.
Future<GeneratedApp> generate({
  required String name,
  String outputDir = '.',
  String org = 'com.example',
  String? kitPath,
  String kitVersion = '^0.2.0',
  bool force = false,
}) async {
  if (!isValidAppName(name)) {
    throw ArgumentError(
      'Tên app "$name" không hợp lệ — phải là snake_case chữ thường, '
      'bắt đầu bằng chữ cái, không phải từ khoá Dart.',
    );
  }
  if (!isValidOrg(org)) {
    throw ArgumentError('Org "$org" không hợp lệ — cần dạng reverse-domain, ví dụ com.example.');
  }

  final targetDir = Directory('$outputDir/$name');
  if (targetDir.existsSync() && targetDir.listSync().isNotEmpty && !force) {
    throw StateError(
      'Thư mục "${targetDir.path}" đã tồn tại và không rỗng — generator '
      'từ chối ghi đè (dùng --force nếu chắc chắn muốn tiếp tục).',
    );
  }

  final createResult = await Process.run('flutter', [
    'create',
    '--org', org,
    '--project-name', name,
    targetDir.path,
  ]);
  if (createResult.exitCode != 0) {
    throw StateError('flutter create thất bại:\n${createResult.stderr}');
  }

  final written = <String>[];
  void write(String relativePath, String content) {
    final file = File('${targetDir.path}/$relativePath');
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(content);
    written.add(relativePath);
  }

  final appName = name;
  write('lib/main.dart', mainDartTemplate(appName: appName));
  write('lib/screens/home_screen.dart', homeScreenTemplate());
  write('lib/screens/widget_showcase_screen.dart', widgetShowcaseScreenTemplate());
  write('lib/screens/game_demo_screen.dart', gameDemoScreenTemplate());
  write('test/widget_test.dart', smokeTestTemplate(appName: appName));
  write('.github/workflows/ci.yml', ciWorkflowTemplate());
  write(_templateVersionFileName, '$templateSchemaVersion\n');

  final pubspecFile = File('${targetDir.path}/pubspec.yaml');
  final patched = patchPubspecWithDependency(
    pubspecFile.readAsStringSync(),
    kitDependencyBlock(kitPath: kitPath, kitVersion: kitVersion),
  );
  pubspecFile.writeAsStringSync(patched);
  written.add('pubspec.yaml (patched)');

  final buildGradleFile = File('${targetDir.path}/android/app/build.gradle.kts');
  buildGradleFile.writeAsStringSync(
    patchAndroidBuildGradleForDesugaring(buildGradleFile.readAsStringSync()),
  );
  written.add('android/app/build.gradle.kts (patched: core library desugaring)');

  return GeneratedApp(path: targetDir.path, writtenFiles: written);
}

/// Reads the `.roy_template_version` marker an earlier [generate] call
/// wrote — `null` if the app was never generated by this tool (no
/// marker file) or the marker is unreadable/malformed. Read-only: this
/// does NOT re-apply a newer template (see [templateSchemaVersion]'s doc
/// for why auto-migration is out of scope).
int? readTemplateVersion(String appDir) {
  final file = File('$appDir/$_templateVersionFileName');
  if (!file.existsSync()) return null;
  return int.tryParse(file.readAsStringSync().trim());
}

Future<void> main(List<String> args) async {
  final options = <String, String>{};
  var force = false;
  String? checkVersionDir;
  for (final arg in args) {
    if (arg == '--force') {
      force = true;
    } else if (arg.startsWith('--check-version=')) {
      checkVersionDir = arg.substring('--check-version='.length);
    } else if (arg.startsWith('--')) {
      final eq = arg.indexOf('=');
      if (eq != -1) options[arg.substring(2, eq)] = arg.substring(eq + 1);
    }
  }

  if (checkVersionDir != null) {
    final version = readTemplateVersion(checkVersionDir);
    if (version == null) {
      stdout.writeln('Không tìm thấy $_templateVersionFileName — app này không phải do generator này tạo, hoặc marker bị xoá.');
      exit(1);
    }
    if (version < templateSchemaVersion) {
      stdout.writeln(
        'Template version $version cũ hơn version hiện tại ($templateSchemaVersion). '
        'Generator này chưa hỗ trợ tự động migrate — xem CHANGELOG để áp dụng thủ công.',
      );
      exit(1);
    }
    stdout.writeln('Template version $version đã là mới nhất.');
    exit(0);
  }

  final name = options['name'];
  if (name == null) {
    stderr.writeln('Thiếu --name=<ten_app>');
    exit(1);
  }

  try {
    final result = await generate(
      name: name,
      outputDir: options['output'] ?? '.',
      org: options['org'] ?? 'com.example',
      kitPath: options['kitPath'],
      kitVersion: options['kitVersion'] ?? '^0.2.0',
      force: force,
    );
    stdout.writeln('Đã tạo app tại ${result.path}:');
    for (final f in result.writtenFiles) {
      stdout.writeln('  $f');
    }
    stdout.writeln('\nTiếp theo: cd ${result.path} && flutter pub get && flutter test');
  } catch (error) {
    stderr.writeln('Generate thất bại: $error');
    exit(1);
  }
}
