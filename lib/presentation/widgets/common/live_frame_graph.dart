import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../core/neon_theme.dart';

enum FrameTimingClass { normal, slow, jank }

FrameTimingClass classifyFrameDuration(Duration duration) {
  if (duration > const Duration(milliseconds: 33)) {
    return FrameTimingClass.jank;
  }
  if (duration > const Duration(microseconds: 16667)) {
    return FrameTimingClass.slow;
  }
  return FrameTimingClass.normal;
}

class BoundedFrameSamples {
  BoundedFrameSamples(this.capacity) {
    if (capacity < 1) {
      throw ArgumentError.value(capacity, 'capacity', 'must be positive');
    }
  }

  final int capacity;
  final List<Duration> values = [];

  void add(Duration duration) {
    values.add(duration);
    if (values.length > capacity) {
      values.removeRange(0, values.length - capacity);
    }
  }
}

/// Live, bounded frame-time graph for a debug/profile QA panel.
class LiveFrameGraph extends StatefulWidget {
  const LiveFrameGraph({
    super.key,
    this.capacity = 100,
    this.sampleFrameTimings,
  });

  final int capacity;
  final Stream<Duration>? sampleFrameTimings;

  @override
  State<LiveFrameGraph> createState() => _LiveFrameGraphState();
}

class _LiveFrameGraphState extends State<LiveFrameGraph> {
  late final BoundedFrameSamples _samples;
  StreamSubscription<Duration>? _subscription;
  Timer? _refreshTimer;
  bool _schedulerCallbackRegistered = false;

  @override
  void initState() {
    super.initState();
    _samples = BoundedFrameSamples(widget.capacity);
    _listen();
  }

  void _listen() {
    final injected = widget.sampleFrameTimings;
    if (injected != null) {
      _subscription = injected.listen(_addSample);
    } else {
      SchedulerBinding.instance.addTimingsCallback(_addTimings);
      _schedulerCallbackRegistered = true;
    }
  }

  void _addTimings(List<FrameTiming> timings) {
    for (final timing in timings) {
      _addSample(timing.totalSpan);
    }
  }

  void _addSample(Duration duration) {
    if (!mounted) return;
    _samples.add(duration);
    _refreshTimer ??= Timer(const Duration(milliseconds: 100), () {
      _refreshTimer = null;
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _subscription?.cancel();
    if (_schedulerCallbackRegistered) {
      SchedulerBinding.instance.removeTimingsCallback(_addTimings);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final samples = _samples.values;
    final jankCount = samples
        .where(
          (sample) => classifyFrameDuration(sample) == FrameTimingClass.jank,
        )
        .length;
    final fps = samples.isEmpty
        ? 0
        : (1000000 / samples.last.inMicroseconds).round();
    return Semantics(
      label: 'Live frame graph, $fps FPS, $jankCount jank frames',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Frame time · $fps FPS · Jank: $jankCount'),
          const SizedBox(height: 8),
          SizedBox(
            height: 72,
            width: double.infinity,
            child: CustomPaint(
              painter: _FrameGraphPainter(samples: List.of(samples)),
            ),
          ),
          const SizedBox(height: 4),
          Text('${samples.length}/${widget.capacity} frames'),
        ],
      ),
    );
  }
}

class _FrameGraphPainter extends CustomPainter {
  const _FrameGraphPainter({required this.samples});

  final List<Duration> samples;

  @override
  void paint(Canvas canvas, Size size) {
    if (samples.isEmpty || size.isEmpty) return;
    const maxMs = 50.0;
    final slotWidth = size.width / samples.length;
    for (var i = 0; i < samples.length; i++) {
      final durationMs = samples[i].inMicroseconds / 1000;
      final height = (durationMs / maxMs * size.height).clamp(1.0, size.height);
      final color = switch (classifyFrameDuration(samples[i])) {
        FrameTimingClass.normal => NeonTheme.lime,
        FrameTimingClass.slow => NeonTheme.gold,
        FrameTimingClass.jank => NeonTheme.red,
      };
      final rect = Rect.fromLTWH(
        i * slotWidth,
        size.height - height,
        math.max(1, slotWidth - 1),
        height,
      );
      canvas.drawRect(rect, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _FrameGraphPainter oldDelegate) =>
      !listEquals(oldDelegate.samples, samples);
}
