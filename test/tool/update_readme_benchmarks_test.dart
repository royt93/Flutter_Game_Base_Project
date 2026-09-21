import 'package:flutter_test/flutter_test.dart';

import '../../tool/update_readme_benchmarks.dart';

void main() {
  group('renderBenchmarkSection', () {
    test('renders a markdown table row per metric, wrapped in markers', () {
      final section = renderBenchmarkSection([
        {
          'name': 'example_app_boot_wall_ms',
          'source': 'realDevice',
          'value': 32318.0,
          'unit': 'ms',
          'recordedAtMs': 1789913922550,
        },
        {
          'name': 'object_pool_allocation_reduction_percent',
          'source': 'hostHeadless',
          'value': 97.5,
          'unit': '%',
          'recordedAtMs': 1789913890220,
        },
      ]);

      expect(section, startsWith(startMarker));
      expect(section, endsWith(endMarker));
      expect(section, contains('| Example App Boot Wall Ms | 32318 ms | realDevice |'));
      expect(section, contains('| Object Pool Allocation Reduction Percent | 97.5% | hostHeadless |'));
    });

    test('renders an empty table body for an empty metric list', () {
      final section = renderBenchmarkSection(const []);
      expect(section, contains('| Metric | Value | Source | Recorded |'));
      expect(section.split('\n').length, 4); // marker, header, separator, marker
    });
  });

  group('replaceBetweenMarkers', () {
    test('replaces content strictly between start/end markers', () {
      const source = 'before\n<!-- A -->\nold\n<!-- B -->\nafter';
      final result = replaceBetweenMarkers(
        source: source,
        start: '<!-- A -->',
        end: '<!-- B -->',
        replacement: '<!-- A -->\nnew\n<!-- B -->',
      );
      expect(result, 'before\n<!-- A -->\nnew\n<!-- B -->\nafter');
    });

    test('leaves text before/after the markers untouched', () {
      const source = 'HEAD\nSTART\nignored\nEND\nTAIL';
      final result = replaceBetweenMarkers(
        source: source,
        start: 'START',
        end: 'END',
        replacement: 'START\nreplaced\nEND',
      );
      expect(result, contains('HEAD'));
      expect(result, contains('TAIL'));
      expect(result, isNot(contains('ignored')));
    });

    test('throws FormatException when start marker missing', () {
      expect(
        () => replaceBetweenMarkers(
          source: 'no markers here',
          start: '<!-- A -->',
          end: '<!-- B -->',
          replacement: 'x',
        ),
        throwsFormatException,
      );
    });

    test('throws FormatException when end marker missing after start', () {
      expect(
        () => replaceBetweenMarkers(
          source: '<!-- A -->\nonly start',
          start: '<!-- A -->',
          end: '<!-- B -->',
          replacement: 'x',
        ),
        throwsFormatException,
      );
    });
  });
}
