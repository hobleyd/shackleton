import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../theme/shackleton_theme.dart';

part 'theme_notifier.g.dart';

@riverpod
class ThemeNotifier extends _$ThemeNotifier {
  ShackletonTheme _theme = ShackletonTheme(size: ThemeFontSize.small);

  @override
  ShackletonTheme build() {
    return _theme;
  }

  void setTheme(ThemeFontSize size) {
    if (_theme.size != size) {
      _theme = ShackletonTheme(size: size);
    }
  }
}
