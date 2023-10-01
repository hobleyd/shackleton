import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:shackleton/providers/selected_entities.dart';

var logger = Logger();

class ProviderLogger extends ProviderObserver {
  @override
  void didUpdateProvider(ProviderBase provider, Object? previousValue, Object? newValue, ProviderContainer container,) {
    logger.d('[${provider.name ?? provider.runtimeType}] value: $newValue');
  }
}
