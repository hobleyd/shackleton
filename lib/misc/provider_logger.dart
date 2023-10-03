import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

var logger = Logger();

class ProviderLogger extends ProviderObserver {
  @override
  void didUpdateProvider(ProviderBase provider, Object? previousValue, Object? newValue, ProviderContainer container,) {
    logger.d('[${provider.name ?? provider.runtimeType}] value: $newValue');
  }
}
