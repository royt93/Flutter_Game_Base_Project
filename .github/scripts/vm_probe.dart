// Read-only VM Service probe used by CI to see what a hung integration test's
// isolate is doing. Usage: dart vm_probe.dart <http-or-ws-vm-service-uri>
// Always exits 0 so a failed probe never changes the CI result.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> args) async {
  if (args.length != 1) {
    stderr.writeln('usage: vm_probe.dart <vm-service-uri>');
    return;
  }
  var uri = args.single.replaceFirst(RegExp('^http'), 'ws');
  if (!uri.endsWith('/ws')) {
    uri = uri.endsWith('/') ? '${uri}ws' : '$uri/ws';
  }

  final pending = <String, Completer<Map<String, dynamic>>>{};
  var nextId = 0;
  WebSocket? socket;
  try {
    socket = await WebSocket.connect(uri).timeout(const Duration(seconds: 10));
    socket.listen((data) {
      final msg = jsonDecode(data as String) as Map<String, dynamic>;
      final waiter = pending.remove('${msg['id']}');
      if (waiter == null) return;
      if (msg['error'] != null) {
        waiter.completeError('${msg['error']}');
      } else {
        waiter.complete(msg['result'] as Map<String, dynamic>);
      }
    });

    Future<Map<String, dynamic>> call(
      String method, [
      Map<String, dynamic> params = const {},
    ]) {
      final id = '${nextId++}';
      final done = Completer<Map<String, dynamic>>();
      pending[id] = done;
      socket!.add(
        jsonEncode({
          'jsonrpc': '2.0',
          'id': id,
          'method': method,
          'params': params,
        }),
      );
      return done.future.timeout(const Duration(seconds: 10));
    }

    final vm = await call('getVM');
    stdout.writeln(
      'vm: ${vm['name']} pid=${vm['pid']} version=${vm['version']}',
    );
    for (final ref in (vm['isolates'] as List).cast<Map<String, dynamic>>()) {
      final id = ref['id'] as String;
      stdout.writeln('isolate ${ref['name']} ($id)');
      try {
        final iso = await call('getIsolate', {'isolateId': id});
        final rpcs = (iso['extensionRPCs'] as List?) ?? const [];
        stdout.writeln(
          '  pauseEvent=${(iso['pauseEvent'] as Map?)?['kind']} '
          'runnable=${iso['runnable']} livePorts=${iso['livePorts']} '
          'integrationTestRpc=${rpcs.contains('ext.flutter.integrationTest')}',
        );
        final stack = await call('getStack', {'isolateId': id, 'limit': 30});
        for (final key in const [
          'frames',
          'awaiterFrames',
          'asyncCausalFrames',
        ]) {
          final frames = (stack[key] as List?) ?? const [];
          stdout.writeln('  $key: ${frames.length}');
          for (final frame in frames.cast<Map<String, dynamic>>().take(15)) {
            final code = (frame['code'] as Map?)?['name'];
            final script =
                ((frame['location'] as Map?)?['script'] as Map?)?['uri'];
            stdout.writeln('    ${frame['kind']} $code $script');
          }
        }
        stdout.writeln(
          '  queuedMessages: ${((stack['messages'] as List?) ?? const []).length}',
        );
      } catch (error) {
        stdout.writeln('  isolate query failed: $error');
      }
    }
  } catch (error) {
    stdout.writeln('probe failed: $error');
  } finally {
    await socket?.close();
  }
}
