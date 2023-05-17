import 'dart:io';

import 'package:flutter/material.dart';

class ShackletonTheme {
  static const TextTheme normalTextTheme = TextTheme(
    titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
    bodyMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
    bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: Colors.black),
    labelSmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black),
  );

  static final ThemeData normal = ThemeData(
    inputDecorationTheme: const InputDecorationTheme(
        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
        errorBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.red, width: 2)),
        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.teal, width: 2))),
    primarySwatch: Colors.teal,
    splashColor: Colors.blueGrey,
    fontFamily: 'San Francisco',
    textTheme: normalTextTheme,
    visualDensity: VisualDensity.compact,
  );
}