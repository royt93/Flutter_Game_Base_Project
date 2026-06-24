import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('QC test case docs release gate', () {
    final docDir = Directory('doc/test');

    test('index references every TC file and every referenced file exists', () {
      final index = File('doc/test/TC-00_index.md').readAsStringSync();
      // TC-[^)]+\.md already matches TC-AUDIT_*.md — no separate branch needed.
      final linked = RegExp(
        r'\((TC-[^)]+\.md)\)',
      ).allMatches(index).map((m) => m.group(1)!).toSet();

      final files = docDir
          .listSync()
          .whereType<File>()
          .map((f) => f.uri.pathSegments.last)
          .where((name) => name != 'TC-00_index.md')
          .toSet();

      for (final link in linked) {
        expect(files, contains(link), reason: 'index links missing file $link');
      }
      for (final file in files) {
        expect(linked, contains(file), reason: '$file is not listed in index');
      }
    });

    test('release closure and audit docs are present', () {
      final tc12 = File('doc/test/TC-12_release_gap_closure.md');
      final audit = File('doc/test/TC-AUDIT_coverage_gaps.md');
      final deviceGate = File('tool/release_device_gate.sh');
      expect(tc12.existsSync(), isTrue);
      expect(audit.existsSync(), isTrue);
      expect(deviceGate.existsSync(), isTrue);

      final tc12Text = tc12.readAsStringSync();
      for (final required in [
        'Install / Update / Data Migration',
        'App Lifecycle / Resume / Timer / Audio',
        'Android Back / Route Stack / Double Tap',
        'Device / Layout / Accessibility Matrix',
        'Localization Full Sweep 22 Locale',
        'Reset Progress Full Sweep',
        'tool/release_device_gate.sh',
      ]) {
        expect(tc12Text, contains(required), reason: 'TC-12 missing $required');
      }
    });

    test('docs do not regress to stale mode counts or known-wrong claims', () {
      for (final f in docDir.listSync().whereType<File>()) {
        final name = f.uri.pathSegments.last;
        if (name == 'TC-AUDIT_coverage_gaps.md') continue;
        final text = f.readAsStringSync();
        expect(text, isNot(contains('11 Side Modes')), reason: name);
        expect(text, isNot(contains('11 chế độ')), reason: name);
        expect(text, isNot(contains('tốn xu nhỏ')), reason: name);
        expect(text, isNot(contains('mảnh sưu tập')), reason: name);
        expect(text, isNot(contains('skin tương ứng')), reason: name);
      }
    });

    test('markdown tables have sane column counts', () {
      for (final f in docDir.listSync().whereType<File>()) {
        final name = f.uri.pathSegments.last;
        final lines = f.readAsLinesSync();
        var inFence = false;
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          // Skip fenced code blocks: a literal '|' inside ``` is not a table row.
          if (line.trimLeft().startsWith('```')) {
            inFence = !inFence;
            continue;
          }
          if (inFence || !line.startsWith('|')) continue;
          final cells = '|'.allMatches(line).length - 1;
          expect(
            cells,
            inInclusiveRange(2, 5),
            reason: '$name:${i + 1} malformed table row: $line',
          );
        }
      }
    });
  });

  group('release asset and package sanity', () {
    test('declared critical assets exist', () {
      for (final path in [
        'asset/audio/bkg.ogg',
        'asset/audio/bkg1.ogg',
        'asset/audio/bkg2.ogg',
        'asset/fonts/Baloo2.ttf',
        'asset/icon/ic_launcher.png',
        'asset/icon/ios_background.png',
        'shaders/neon_glow.frag',
      ]) {
        expect(File(path).existsSync(), isTrue, reason: '$path missing');
      }

      for (var i = 1; i <= 24; i++) {
        final n = i.toString().padLeft(2, '0');
        expect(
          File('asset/audio/notes/n$n.mp3').existsSync(),
          isTrue,
          reason: 'missing note n$n',
        );
      }
    });

    test('Android package id is stable', () {
      final gradle = File('android/app/build.gradle.kts').readAsStringSync();
      expect(gradle, contains('namespace = "com.galaxyjoy.neon_jewels"'));
      expect(gradle, contains('applicationId = "com.galaxyjoy.neon_jewels"'));
    });
  });
}
