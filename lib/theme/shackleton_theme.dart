import 'dart:io';

import 'package:flutter/material.dart';

enum ThemeFontSize { small, medium, large }

class ShackletonTheme {
  ThemeFontSize size = ThemeFontSize.small;
  late ThemeData theme;

  ShackletonTheme({required this.size}) {
    buildThemeData();
  }

  static const TextTheme normalTextTheme = TextTheme(
    titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
    bodyMedium: TextStyle(fontSize: 13, fontWeight: FontWeight.w400),
    labelMedium: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
    bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: Colors.black),
    labelSmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black),
  );

  void buildThemeData() {
    theme = ThemeData(
      inputDecorationTheme: const InputDecorationTheme(
          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
          errorBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.red, width: 2)),
          focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.teal, width: 2))),
      primarySwatch: Colors.teal,
      splashColor: Colors.blueGrey,
      fontFamily: Platform.isMacOS ? 'San Francisco' : 'OpenSans',
      textTheme: size == ThemeFontSize.small ? normalTextTheme : normalTextTheme,
      textSelectionTheme: const TextSelectionThemeData(
        selectionHandleColor: Color(0xf0e8e4df),
      ),
      visualDensity: VisualDensity.compact,
    );
  }
}