import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Manages a persistent exiftool process in -stay_open mode.
///
/// Commands are serialised: each caller awaits its own response before the
/// next command is sent to stdin, so no response interleaving is possible.
///
/// Usage:
///   final daemon = ExifToolDaemon('/usr/bin/exiftool');
///   final json = await daemon.execute(['-j', '-subject', '/path/file.jpg']);
///   await daemon.stop();
class ExifToolDaemon {
  final String _exifToolPath;

  Process? _process;
  StreamSubscription<String>? _stdoutSub;
  StreamSubscription<String>? _stderrSub;
  final StringBuffer _buf = StringBuffer();
  Completer<String>? _pending;

  // Serialisation: each execute() captures the previous lock and installs its own.
  // Callers calling execute() concurrently will form a chain and run in order.
  Future<void>? _lock;

  ExifToolDaemon(this._exifToolPath);

  /// Sends [args] to the daemon and returns stdout up to the {ready} marker.
  ///
  /// Concurrent callers are queued and executed in order.
  Future<String> execute(List<String> args) {
    // Both assignments happen synchronously, before any await, so the chain
    // is always correct even when many callers call execute() concurrently.
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
        _pending = Completer<String>();
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

  Future<void> _ensureStarted() async {
    if (_process != null) return;
    _process = await Process.start(_exifToolPath, ['-stay_open', 'True', '-@', '-']);
    _stdoutSub = _process!.stdout
        .transform(utf8.decoder)
        .listen(_onStdout, onDone: _restart, onError: (_) => _restart());
    _stderrSub = _process!.stderr.transform(utf8.decoder).listen((_) {});
  }

  void _onStdout(String chunk) {
    _buf.write(chunk);
    final s = _buf.toString();
    final match = RegExp(r'\{ready\w*\}').firstMatch(s);
    if (match != null && _pending != null && !_pending!.isCompleted) {
      final output = s.substring(0, match.start).trim();
      _buf.clear();
      _pending!.complete(output);
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
