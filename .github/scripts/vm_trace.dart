// Read-only VM Service event tracer used by CI (DISC-02). Connects directly to
// the app's VM service (a second client alongside DDS), subscribes to the
// Extension, Isolate and Logging streams, and prints one timestamped line per
// event so a hung run shows whether the test-start message ever arrived.
// Usage: dart vm_trace.dart <http-or-ws-vm-service-uri> [seconds]
// Always exits 0 so it can never change the CI result.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

String _now() => DateTime.now().toUtc().toIso8601String();

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln('usage: vm_trace.dart <vm-service-uri> [seconds]');
    return;
  }
  var uri = args.first.replaceFirst(RegExp('^http'), 'ws');
  if (!uri.endsWith('/ws')) {
    uri = uri.endsWith('/') ? '${uri}ws' : '$uri/ws';
  }
  final seconds = args.length > 1 ? int.tryParse(args[1]) ?? 1500 : 1500;

  try {
    final socket = await WebSocket.connect(
      uri,
    ).timeout(const Duration(seconds: 10));
    var id = 0;
    void send(String method, [Map<String, dynamic> params = const {}]) {
      socket.add(
        jsonEncode({
          'jsonrpc': '2.0',
          'id': '${id++}',
          'method': method,
          'params': params,
        }),
      );
    }

    final done = Completer<void>();
    socket.listen(
      (data) {
        final msg = jsonDecode(data as String) as Map<String, dynamic>;
        if (msg['method'] == 'streamNotify') {
          final params = msg['params'] as Map<String, dynamic>;
          final event = params['event'] as Map<String, dynamic>;
          final kind = event['kind'];
          final extra = switch (kind) {
            'Extension' =>
              ' ext=${event['extensionKind']} bytes=${jsonEncode(event['extensionData']).length}',
            'Logging' =>
              ' logger=${(event['logRecord'] as Map?)?['loggerName']?['valueAsString']}',
            _ => '',
          };
          stdout.writeln(
            '[vm-trace ${_now()}] ${params['streamId']} $kind$extra',
          );
        } else if (msg['error'] != null) {
          stdout.writeln('[vm-trace ${_now()}] rpc error ${msg['error']}');
        }
      },
      onDone: () {
        stdout.writeln('[vm-trace ${_now()}] socket closed');
        if (!done.isCompleted) done.complete();
      },
    );
    for (final stream in const ['Extension', 'Isolate', 'Logging', 'Debug']) {
      send('streamListen', {'streamId': stream});
    }
    stdout.writeln('[vm-trace ${_now()}] listening on $uri');
    await Future.any([
      done.future,
      Future<void>.delayed(Duration(seconds: seconds)),
    ]);
    await socket.close();
  } catch (error) {
    stdout.writeln('[vm-trace ${_now()}] failed: $error');
  }
}
