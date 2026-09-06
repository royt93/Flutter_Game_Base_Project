import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/audio_manager.dart';
import '../../core/locale_service.dart';
import '../../core/storage_service.dart';
import '../../core/utils/clamped_clock.dart';

/// Hidden debug/QA overlay — a small long-press trigger in a screen corner
/// that opens a read-only panel dumping live internal package state
/// (every `StorageService` key/value, audio mute, current locale, and the
/// `clampedClock` rewind-blocked count) so a QA tester can self-diagnose
/// on-device without plugging in DevTools.
///
/// Gated exactly like [dlog] (`lib/core/debug_log.dart`) — `kDebugMode ||
/// kProfileMode` — so a QA build (which is typically a profile build, not a
/// debug build) still gets it, while a release build never builds the
/// trigger or panel at all (this widget degrades to exactly [child]).
///
/// Usage — wrap your app's root widget:
/// ```dart
/// DebugQaOverlay(child: MaterialApp(...));
/// ```
class DebugQaOverlay extends StatefulWidget {
  const DebugQaOverlay({super.key, required this.child});

  final Widget child;

  @override
  State<DebugQaOverlay> createState() => _DebugQaOverlayState();
}

class _DebugQaOverlayState extends State<DebugQaOverlay> {
  bool _open = false;
  Timer? _refreshTimer;

  void _toggle() {
    setState(() => _open = !_open);
    _refreshTimer?.cancel();
    _refreshTimer = _open
        ? Timer.periodic(
            const Duration(milliseconds: 500),
            (_) => setState(() {}),
          )
        : null;
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode && !kProfileMode) return widget.child;

    return Stack(
      children: [
        widget.child,
        if (_open) _Panel(onClose: _toggle),
        // Kept on top of the panel (rather than under it) so long-pressing
        // the corner again always closes the panel too, not just tapping
        // outside it.
        Positioned(
          top: 0,
          right: 0,
          width: 48,
          height: 48,
          child: GestureDetector(
            key: const Key('debugQaOverlayTrigger'),
            behavior: HitTestBehavior.opaque,
            onLongPress: _toggle,
            child: const SizedBox.expand(),
          ),
        ),
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final storage = StorageService.maybe?.exportAll() ?? const {};
    final audioMuted = AudioManager.maybe?.muted.value;
    final locale = LocaleService.maybe?.current.value;

    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onClose, // tap outside the panel dismisses it
        child: Container(
          color: Colors.black54,
          child: Center(
            child: GestureDetector(
              onTap: () {}, // absorb taps inside the panel
              child: Container(
                width: 320,
                constraints: const BoxConstraints(maxHeight: 480),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Debug QA',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: onClose,
                        ),
                      ],
                    ),
                    // Everything below the title bar scrolls as one region —
                    // a Flexible here (rather than sizing to content) means
                    // this can never overflow the fixed-height dialog no
                    // matter how many storage keys or how long the values.
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Audio muted: '
                              '${audioMuted?.toString() ?? "not registered"}',
                            ),
                            Text(
                              'Locale: ${locale?.toString() ?? "not registered"}',
                            ),
                            Text(
                              'Clock rewind blocked: $clockRewindBlockedCount',
                            ),
                            const Divider(),
                            for (final entry in storage.entries)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 2,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        entry.key,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        '${entry.value}',
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.right,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
