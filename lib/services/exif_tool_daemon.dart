import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Manages a persistent exiftool process in -stay_open mode.
///
/// Commands are serialised: each caller awaits its own response before the
/// next command is sent to stdin. Responses are returned as raw [Uint8List]
/// bytes, which supports both JSON/text output and binary output (e.g. -b
/// for embedded thumbnails). Callers that need text use [execute]; callers
/// that need bytes use [executeBytes].
class ExifToolDaemon {
  final String _exifToolPath;

  Process? _process;
  StreamSubscription<List<int>>? _stdoutSub;
  StreamSubscription<String>? _stderrSub;
  // BytesBuilder stores each incoming chunk as a Uint8List reference without
  // copying, avoiding the ~8× overhead of List<int> on 64-bit VMs.
  final _buf = BytesBuilder(copy: false);
  // Separate ring-buffer for {ready} detection — kept small so scanning is O(1).
  var _tail = <int>[];
  Completer<Uint8List>? _pending;

  // Serialisation: each execute captures the previous lock and installs its own.
  Future<void>? _lock;

  ExifToolDaemon(this._exifToolPath);

  /// Sends [args] to the daemon and returns the raw byte response (content
  /// before the trailing `{ready}` marker).
  ///
  /// Concurrent callers queue and execute in order.
  Future<Uint8List> executeBytes(List<String> args) {
    // Both assignments run synchronously, so the chain is always correct
    // even when many callers call this concurrently.
    final prev = _lock;
    final done = Completer<void>();
    _lock = done.future;

    return Future(() async {
      try {
        await prev;
      } catch (_) {
        // previous command failed — still proceed with this one
      }
      try {
        await _ensureStarted();
        _pending = Completer<Uint8List>();
        _buf.takeBytes(); // discard any leftover bytes and reset
        _tail = [];
        for (final arg in args) {
          _process!.stdin.writeln(arg);
        }
        _process!.stdin.writeln('-execute');
        return await _pending!.future.timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            _restart();
            throw TimeoutException('exiftool daemon timed out');
          },
        );
      } finally {
        done.complete();
      }
    });
  }

  /// Sends [args] and returns the response decoded as UTF-8.
  Future<String> execute(List<String> args) async {
    return utf8.decode(await executeBytes(args));
  }

  Future<void> _ensureStarted() async {
    if (_process != null) return;
    _process = await Process.start(_exifToolPath, ['-stay_open', 'True', '-@', '-']);
    _stdoutSub = _process!.stdout.listen(
      _onBytes,
      onDone: _restart,
      onError: (_) => _restart(),
    );
    _stderrSub = _process!.stderr.transform(utf8.decoder).listen((_) {});
  }

  void _onBytes(List<int> chunk) {
    _buf.add(chunk);
    _tail.addAll(chunk);
    // Keep only the last 30 bytes for {ready} detection.
    if (_tail.length > 30) _tail = _tail.sublist(_tail.length - 30);

    if (_pending == null || _pending!.isCompleted) return;

    // The {ready} marker is pure ASCII so we can safely scan just the tail
    // without decoding potentially large binary payloads.
    final tail = String.fromCharCodes(_tail);
    final match = RegExp(r'\{ready\w*\}\s*').firstMatch(tail);
    if (match != null) {
      // Compute where in the full response the {ready} marker starts.
      final trimAt = _buf.length - _tail.length + match.start;
      final all = _buf.takeBytes(); // assembles chunks into one Uint8List and resets
      _tail = [];
      _pending!.complete(Uint8List.sublistView(all, 0, trimAt));
    }
  }

  void _restart() {
    _process = null;
    _stdoutSub?.cancel();
    _stdoutSub = null;
    _stderrSub?.cancel();
    _stderrSub = null;
    if (_pending != null && !_pending!.isCompleted) {
      _pending!.completeError(Exception('exiftool daemon exited unexpectedly'));
    }
  }

  Future<void> stop() async {
    if (_process == null) return;
    try {
      _process!.stdin.writeln('-stay_open');
      _process!.stdin.writeln('False');
      _process!.stdin.writeln('-execute');
      await _process!.stdin.close();
    } catch (_) {}
    await _stdoutSub?.cancel();
    await _stderrSub?.cancel();
    _process = null;
  }
}
