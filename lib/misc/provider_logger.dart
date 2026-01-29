import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

var logger = Logger();

final class ProviderLogger extends ProviderObserver {
  @override
  void didUpdateProvider(ProviderObserverContext context, Object? previousValue, Object? newValue,) {
    logger.d('[${context.provider.name ?? context.provider.runtimeType}] value: $newValue');
  }
}
