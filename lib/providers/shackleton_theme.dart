import 'dart:io';

import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'shackleton_theme.g.dart';

@Riverpod(keepAlive: true)
class ShackletonTheme extends _$ShackletonTheme {
  @override
  ThemeData build() {
    return buildThemeData(12);
  }

  ThemeData buildThemeData(double fontSize) {
    return ThemeData(
      colorSchemeSeed: Colors.teal,
      fontFamily: Platform.isMacOS ? 'San Francisco' : 'OpenSans',
      inputDecorationTheme: const InputDecorationTheme(
          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
          errorBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.red, width: 2)),
          focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.teal, width: 2))),
      textTheme: TextTheme(
        titleSmall:  TextStyle(fontSize: fontSize - 2, fontWeight: FontWeight.w700),
        bodyMedium:  TextStyle(fontSize: fontSize + 1, fontWeight: FontWeight.w400),
        labelMedium: TextStyle(fontSize: fontSize + 1, fontWeight: FontWeight.w700),
        bodySmall:   TextStyle(fontSize: fontSize, fontWeight: FontWeight.w400, color: Colors.black),
        labelSmall:  TextStyle(fontSize: fontSize, fontWeight: FontWeight.w700, color: Colors.black),
      ),
      textSelectionTheme: const TextSelectionThemeData(
        selectionHandleColor: Color(0xf0e8e4df),
      ),
      useMaterial3: true,
      visualDensity: VisualDensity.compact,
    );
  }

  void setFontSize(double fontSize) {
    state = buildThemeData(fontSize);
  }
}
