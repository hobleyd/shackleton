import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../theme/shackleton_theme.dart';

part 'theme.g.dart';

@riverpod
class Theme extends _$Theme {
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
