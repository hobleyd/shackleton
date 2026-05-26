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
  final List<int> _buf = [];
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
        _buf.clear();
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
    _buf.addAll(chunk);
    if (_pending == null || _pending!.isCompleted) return;

    // The {ready} marker is pure ASCII so we can safely scan the tail of the
    // buffer without decoding potentially large binary payloads.  Searching
    // only the last 30 bytes is sufficient because {ready} is always the last
    // thing exiftool writes for a given command.
    final searchFrom = _buf.length > 30 ? _buf.length - 30 : 0;
    final tail = String.fromCharCodes(_buf, searchFrom);
    final match = RegExp(r'\{ready\w*\}\s*').firstMatch(tail);
    if (match != null) {
      final responseEnd = searchFrom + match.start;
      final response = Uint8List.fromList(_buf.sublist(0, responseEnd));
      _buf.clear();
      _pending!.complete(response);
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
