import 'package:flutter/material.dart';
import 'package:roy_casual_kit/roy_casual_kit.dart';

class AnalyticsAckDemoScreen extends StatefulWidget {
  const AnalyticsAckDemoScreen({super.key});

  @override
  State<AnalyticsAckDemoScreen> createState() => _AnalyticsAckDemoScreenState();
}

class _AnalyticsAckDemoScreenState extends State<AnalyticsAckDemoScreen> {
  final _storage = _DemoStorage();
  final _consent = _DemoConsent();
  late final PrivacyAwareAnalyticsQueue _queue;
  bool _busy = false;
  String _status = 'Ready';

  @override
  void initState() {
    super.initState();
    _queue = PrivacyAwareAnalyticsQueue(
      storage: _storage,
      storageKey: _DemoStorage.queueKey,
      consent: _consent,
      registry: SdkEventSchemaRegistry()
        ..register(EventSchema(name: 'demo_ack_event', version: 1, params: {})),
      uploader: (_) async {},
    );
  }

  Future<void> _enqueue() async {
    setState(() => _busy = true);
    try {
      final accepted = await _queue.enqueueDurably('demo_ack_event');
      if (mounted) {
        setState(
          () => _status = accepted ? 'Event queued' : 'Consent required',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _flush() async {
    setState(() => _busy = true);
    try {
      final result = await _queue.flush();
      if (mounted) {
        setState(() {
          _status = switch (result) {
            SdkSuccess<int>() => 'Flush saved; retry complete',
            SdkFailure<int>(kind: SdkErrorKind.storage) =>
              'ACK received; save failed, event retained for retry',
            SdkFailure<int>() => 'Consent required',
          };
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _queue.dispose();
    _consent.onClose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Analytics ACK demo')),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Local fake uploader and simulated RAM storage failure. '
            'No network, ads or app consent changes.',
          ),
          const SizedBox(height: 16),
          Text(
            'Pending: ${_queue.pendingCount} · '
            'Uploaded: ${_queue.auditSnapshot.uploaded}',
            key: const ValueKey('analyticsAckCounts'),
          ),
          Text(_status, key: const ValueKey('analyticsAckStatus')),
          const SizedBox(height: 16),
          ElevatedButton(
            key: const ValueKey('analyticsAckGrant'),
            onPressed: _busy
                ? null
                : () {
                    _consent.grant(ConsentCategory.analytics);
                    setState(() => _status = 'Demo consent granted');
                  },
            child: const Text('Grant demo consent'),
          ),
          ElevatedButton(
            key: const ValueKey('analyticsAckEnqueue'),
            onPressed: _busy ? null : _enqueue,
            child: const Text('Queue event'),
          ),
          ElevatedButton(
            key: const ValueKey('analyticsAckFail'),
            onPressed: _busy
                ? null
                : () {
                    _storage.failNextRemoval = true;
                    setState(
                      () => _status = 'Next ACK save will fail (simulation)',
                    );
                  },
            child: const Text('Fail next ACK save'),
          ),
          ElevatedButton(
            key: const ValueKey('analyticsAckFlush'),
            onPressed: _busy ? null : _flush,
            child: const Text('Flush / retry'),
          ),
        ],
      ),
    ),
  );
}

class _DemoStorage extends StorageService {
  _DemoStorage() : super(null);
  static const queueKey = 'analytics_ack_demo';
  bool failNextRemoval = false;

  @override
  Future<void> remove(String key) {
    if (key == queueKey && failNextRemoval) {
      failNextRemoval = false;
      return Future.error(StateError('simulated ACK removal failure'));
    }
    return super.remove(key);
  }
}

class _DemoConsent extends ConsentStateService {
  _DemoConsent() : super(policyVersion: 1);
  bool _granted = false;

  @override
  bool isGranted(ConsentCategory category) =>
      category == ConsentCategory.analytics && _granted;

  @override
  void grant(ConsentCategory category) {
    if (category != ConsentCategory.analytics) return;
    _granted = true;
    revision.value++;
  }
}
